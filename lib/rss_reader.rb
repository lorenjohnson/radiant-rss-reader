require 'uri'
require 'net/http'
require 'feedparser/feedparser'

module RssReader
  include Radiant::Taggable
  
  def fetch_rss(uri, cache_time)
    c = File.join(ActionController::Base.page_cache_directory, uri.tr(':/','_'))
    if (cached_feed = feed_for(IO.read(c)) rescue nil)
      return cached_feed if File.mtime(c) > (Time.now - cache_time)
      since = File.mtime(c).httpdate
    else
      since = "1970-01-01 00:00:00"
    end
    u = URI::parse(uri)
    begin
      http = Net::HTTP.start(u.host, u.port)
      answer = http.get("#{u.path}", { "If-Modified-Since" => since })
      feed = feed_for(answer.body)
    rescue
      return cached_feed
    end
    case answer.code
    when '304'
      return cached_feed
    when '200'
      File.open(c,'w+') { |fp| fp << answer.body }
      return feed
    else
      raise StandardError, "#{answer.code} #{answer.message}"
    end
  end
  
  def feed_for(str)
    FeedParser::Feed.new(str)
  end

  def cache?
    false
  end

    tag "feed" do |tag|
      tag.expand
    end


    # feed:items tag attributes
    # =========================
    #
    # url:        URL of the feed. No relative URLs, must be absolute.
    # cache_time: length of time to cache the feed before seeing if it's been updated
    # order:      works just like SQL 'ORDER BY' clauses, e.g. order='creator date desc'
    #             orders first by creator ascending, then date descending
    # limit:      only return the first x items (after any ordering)
    tag "feed:items" do |tag|
      attr = tag.attr.symbolize_keys
      result = []
      begin
        items = fetch_rss(attr[:url], attr[:cache_time].to_i || 900).items
      rescue
        return "<!-- RssReader error: #{$!} -->"
      end
      if attr[:order]
        (tokens = attr[:order].split.map {|t| t.downcase}.reverse).each_index do |i|
          t = tokens[i]
          if ['title','link','content','date','creator'].include? t
            items.sort! {|x,y| (tokens[i-1] == 'desc') ? (y.send(t) <=> x.send(t)) : (x.send(t) <=> y.send(t)) }
          end
        end
      end
      if attr[:limit]
        items = items.slice(0,attr[:limit].to_i)
      end
      items.each_index do |i|
      	tag.locals.item = items[i]
      	tag.locals.last_item = items[i-1] if i > 0
        result << tag.expand
      end
      result
    end
    
    #Contents of feed:header tag block are only rendered if item.send(attr[:for])
    #is different from the last item. E.g. use like this in an ordered-by-creator feed:
    #
    #  <r:feed:header for="creator">
    #    <h2><r:feed:creator /></h2>
    #  </r:feed:header>
    #  <r:feed:content />
    #
    # for='date' chunks by days (i.e. not hours or seconds, thankfully)
    tag "feed:header" do |tag|
      attr = tag.attr.symbolize_keys
      grouping = attr[:for] || 'date'
      unless tag.locals.last_item
        tag.expand
      else
        if ['title','link','content','creator'].include? grouping
          tag.expand if tag.locals.item.send(grouping) != tag.locals.last_item.send(grouping)
        elsif grouping == 'date'
          tag.expand if tag.locals.item.send(grouping).strftime("%j%Y") != tag.locals.last_item.send(grouping).strftime("%j%Y")
        end
      end
    end
    
    tag "feed:title" do |tag|
      tag.locals.item.title
    end

    tag "feed:link" do |tag|
      attr = tag.attr.symbolize_keys
      if attr[:no_a]
        tag.locals.item.link
      else
        options = tag.attr.dup
        attributes = options.inject('') { |s, (k, v)| s << %{#{k.downcase}="#{v}" } }.strip
        attributes = " #{attributes}" unless attributes.empty?
        href = tag.locals.item.link
        text = tag.double? ? tag.expand : tag.locals.item.title
        %{<a href="#{href}"#{attributes}>#{text}</a>}
      end
    end

    # feed:content tag attributes
    # ===========================
    #
    # max_length: no-nonsense truncation
    # no_p:       takes out just the enclosing <p></p> tags that FeedParser puts in
    # no_html:    takes out *all* html
    #
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
      if result
        result = result.gsub(/\A<p>(.*)<\/p>\z/m,'\1') if attr[:no_p]
        result = result.gsub(/<[^>]+>/, '') if attr[:no_html]
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
  
