require 'uri'
require 'net/http'
require 'feedparser'

class RssReader < Page

  CACHE_DIR = '/tmp'

  def fetch(uri)
    c = File.join(CACHE_DIR, uri.tr(':/','_'))
    if File.exist?(c)
      since = File.mtime(c).httpdate
    else
      since = "1970-01-01 00:00:00"
    end
    u = URI::parse(uri)
    http = Net::HTTP.start(u.host, u.port)
    answer = http.get("#{u}", { "If-Modified-Since" => since })
    case answer.code
    when '304'
      return IO.read(c)
    when '200'
      File.new(c, 'w').write(answer.body)
      return answer.body
    else
      return ''
    end
  end

  def fetch_rss(uri)
    FeedParser::Feed.new(fetch(uri))
  end

  def cache?
    false
  end

  tag "feed" do |tag|
    tag.expand
  end

  tag "feed:items" do |tag|
    attr = tag.attr.symbolize_keys
    result = []
    items = fetch_rss(attr[:url]).items
    if attr[:limit]
      items = items.slice(0,attr[:limit].to_i)
    end
    items.each do |item|
    	tag.locals.item = item
      result << tag.expand
    end
    result
  end

  tag "feed:title" do |tag|
    tag.locals.item.title
  end

  tag "feed:link" do |tag|
    options = tag.attr.dup
    attributes = options.inject('') { |s, (k, v)| s << %{#{k.downcase}="#{v}" } }.strip
    attributes = " #{attributes}" unless attributes.empty?
    href = tag.locals.item.link
    text = tag.double? ? tag.expand : tag.locals.item.title
    %{<a href="#{href}"#{attributes}>#{text}</a>}
  end

  tag "feed:content" do |tag|
    attr = tag.attr.symbolize_keys
    result = tag.locals.item.content
    if attr[:max_length]
      l = tag.locals.item.content.size()
    	maxl = attr[:max_length].to_i
    	if l > maxl
    	  result = tag.locals.item.content[0..maxl] + ' ...'
    	end
    end
    if result and attr[:no_html]
      result = result.gsub(/<[^>]+>/, '')
    end
    result
  end

  tag "feed:date" do |tag|
    # Could change this default format string to '%b %d' if you prefer
    format = (tag.attr['format'] || '%A, %B %d, %Y') 
    if date = tag.locals.item.date
      date.strftime(format)
    end
  end

  tag "feed:creator" do |tag|
    tag.locals.item.creator
  end

end
  
