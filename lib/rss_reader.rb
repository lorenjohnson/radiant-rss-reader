require 'uri'
require 'net/http'
require 'net/https'
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
      http = Net::HTTP.new(u.host, u.port)
      http.use_ssl = true if u.port == 443
      answer = http.get("#{u.request_uri}", {"If-Modified-Since" => since, 'User-Agent' => 'RadiantCMS rss_reader Extension 0.1'} )
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


 desc %{
    Iterates through items in an rss feed provided as an absolute url to the @url@ attribute.
    
    Optional attributes:

    * @cache_time@: length of time to cache the feed before seeing if it's been updated
    * @order@:      works just like SQL 'ORDER BY' clauses, e.g. order='creator date desc' orders first by creator ascending, then date descending
    * @limit@:      only return the first x items (after any ordering)
    
    *Usage:*

    <pre><code><r:find:items url="http://somefeed.com/rss" [cache_time="3600"] [order="creator date desc"] [limit="5"]>...</r:feed:items></code></pre>
    }
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

 desc %{
    Used when the @feed:items@ tag uses the @order@ attribute. Will enter this block each time the value of the @for@ attribute is different from the previous feed item. Note: Using "date" as the @for@ attribute group by day
    
    *Usage:*

    <pre><code><r:feed:header for="{creator|title|link|content|date}">...</r:feed:header></code></pre>
    }    

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
      options = tag.attr.dup
      attributes = options.inject('') { |s, (k, v)| s << %{#{k.downcase}="#{v}" } }.strip
      attributes = " #{attributes}" unless attributes.empty?
      href = tag.locals.item.link
      text = tag.double? ? tag.expand : tag.locals.item.title
      %{<a href="#{href}"#{attributes}>#{text}</a>}
    end
    
    tag "feed:uri" do |tag|
      tag.locals.item.link
    end

 desc %{
    Display the contents of the rss feed item

    Optional attributes:

    * @max_length@: no-nonsense truncation
    * @no_p@:       takes out just the enclosing paragraph tags that FeedParser puts in
    * @no_html@:    takes out *all* html
    
    *Usage:*

    <pre><code><r:feed:content  [max_length="140"] [no_p="true"] [no_html="true"]/></code></pre>
    }   

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

 desc %{
    Display the date of the rss feed item

    Optional attributes:

    * @format@: Default is "%A, %B %d, %Y" can be changed to "%b %d"
    
    *Usage:*

    <pre><code><r:feed:date  [format="%b %d"]/></code></pre>
    } 
    tag "feed:date" do |tag|
      format = (tag.attr['format'] || '%A, %B %d, %Y') 
      if date = tag.locals.item.date
        date.strftime(format)
      end
    end

 desc %{
    Display the creator of the rss feed item
    
    *Usage:*

    <pre><code><r:feed:creator/></code></pre>
    } 
    tag "feed:creator" do |tag|
      tag.locals.item.creator
    end

end
  
