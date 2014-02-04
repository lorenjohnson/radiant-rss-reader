require 'uri'
require 'net/http'
require 'net/https'
require 'feedparser/feedparser'
require 'htmlentities'

module RssReader
  include Radiant::Taggable
  include ActionView::Helpers::DateHelper
  
  def fetch_rss(uri, cache_time)
    c = File.join(ActionController::Base.page_cache_directory, uri.tr(':/','_'))
    if (cached_feed = feed_for(IO.read(c)) rescue nil)
      if File.mtime(c) > (Time.now - cache_time)
        return cached_feed 
      end
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

  def sql_sort(items, query)
    columns = query.split(',')
    instructions = columns.map do |column|
      col, order = column.split
      order ||= 'asc'
      [col, order.downcase != 'desc']
    end

    items.sort do |first, second|
      first_values, second_values = instructions.map { |column, ascending|
        duple = [first[column], second[column]]
        ascending ? duple : duple.reverse
      }.transpose
      first_values <=> second_values
    end
  end

  tag "feed" do |tag|
    tag.expand
  end

  desc %{
    Iterates through items in an rss feed provided as an absolute url to the @url@ attribute.
    
    Optional attributes:

    * @cache_time@: length of time to cache the feed before seeing if it's been updated
    * @order@:      works just like SQL 'ORDER BY' clauses, e.g. order='creator, date desc' orders first by creator ascending, then date descending
    * @limit@:      only return the first x items (after any ordering)
    * @matching@:   only return items whose string representation matches this regular expression
    
    *Usage:*

    <pre><code><r:feed:items url="http://somefeed.com/rss" [cache_time="3600"] [order="creator, date desc"] [limit="5"]>...</r:feed:items></code></pre>
  }
  tag "feed:items" do |tag|
    attr = tag.attr.symbolize_keys
    result = ""

    feed_uri = URI.parse(attr[:url])
    tag.locals.feed_uri = feed_uri
    begin
      items = fetch_rss(feed_uri.to_s, attr[:cache_time].to_i || 900).items
    rescue
      return "<!-- RssReader error: #{$!} -->"
    end

    items = sql_sort(items, attr[:order]) if attr[:order]
    items = items.slice(0, attr[:limit].to_i) if attr[:limit]

    attr[:matching] = Regexp.new(attr[:matching]) if attr[:matching]
    last_item = nil
    items.each do |item|
      next if attr[:matching] and !item.to_s.match(attr[:matching])
    	tag.locals.item = item
    	tag.locals.last_item = last_item if last_item
      result << tag.expand.strip
      last_item = item
    end

    result
  end

  desc %{
    The number of items in the feed.

    Optional attributes:

    * @limit@:      return x or the number of items, which ever is lesser
    * @cache_time@: length of time to cache the feed before seeing if it's been updated
    * @matching@:   only count items whose string representation matches this regular expression

    *Usage:*

        <pre><code><r:feed:item_count url="http://somefeed.com/rss" [cache_time="3600"] [limit="5"] /></code></pre>
  }
  tag "feed:item_count" do |tag|
    attr = tag.attr.symbolize_keys
    result = []
    begin
      items = fetch_rss(attr[:url], attr[:cache_time].to_i || 900).items
    rescue
      return "<!-- RssReader error: #{$!} -->"
    end
    items = items.slice(0, attr[:limit].to_i) if attr[:limit]
    pattern = Regexp.new(attr[:matching]) if attr[:matching]
    items.reject! {|i| i.to_s.match(pattern).nil? } if attr[:matching]
    items.size.to_s
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
  
  desc %{
    Display the title of the rss feed item

    Optional attributes:
    * @filter@:     displays only the portion matching the regular expression
    
    *Usage:*

    <pre><code><r:feed:content  [max_length="140"] [no_p="true"] [no_html="true"]/></code></pre>
  }   
  tag "feed:title" do |tag|
    attr = tag.attr.symbolize_keys
    result = tag.locals.item.title || ""
    result.gsub!(/(&(amp;)?)/, '&amp;')
    if attr[:filter]
      r = Regexp.new(attr[:filter])
      md = result.match(r)
      result = md.to_a.first if md
    end
    result.strip
  end

  tag "feed:link" do |tag|
    options = tag.attr.dup
    attributes = options.inject('') { |s, (k, v)| s << %{#{k.downcase}="#{v}" } }.strip
    attributes = " #{attributes}" unless attributes.empty?
    href = tag.locals.item.link
    text = tag.double? ? tag.expand : tag.locals.item.title.gsub(/(&(amp;)?)/, '&amp;')
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
    * @unescape_html@:    attempts to unescape HTML in the content
    * @filter@:     displays only the portion matching the regular expression
    
    *Usage:*

    <pre><code><r:feed:content  [max_length="140"] [no_p="true"] [no_html="true"] [unescape_html="false"] /></code></pre>
  }   

  tag "feed:content" do |tag|
    attr = tag.attr.symbolize_keys
    result = tag.locals.item.content || ""
    if attr[:filter]
      r = Regexp.new(attr[:filter])
      md = result.match(r)
      result = md.to_a.first if md
    end
    if result
      result = HTMLEntities.new.decode(result) if attr[:unescape_html] == 'true'
      if attr[:no_p] == 'true'
        result.gsub!('<p>', '')
        result.gsub!('</p>', '')
      end
      result.gsub!(/<[^>]+>/, '') if attr[:no_html] == 'true'
    end
    result.strip!
    result.gsub!(/\s+/, ' ')
    if attr[:max_length]
      l = result.size
    	maxl = attr[:max_length].to_i
    	if l > maxl
    	  result = result[0..maxl]
    	end
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
    Display the time elapsed since the item was posted in a friendly format

    Optional attributes:

    * @use_timestamp_after@: This specifies how many days must elapse before a timestamp
        is displayed instead of elapsed time. It defaults to 10 days. Specify 0 to never use a timestamp.
    * @format@: Timestamp format to use if @use_timestamp_after@ is specified. Default is "%A, %B %d, %Y".

    *Usage:*

    <pre><code><r:feed:time_elapsed [format="%b %d"]/></code></pre>
  }
  tag "feed:time_elapsed" do |tag|
    format = (tag.attr['format'] || '%d %b %Y')
    num_days = tag.attr['use_timestamp_after'].blank? ? 10 : tag.attr['use_timestamp_after'].to_i
    from_time = tag.locals.item.date.to_time
    to_time = Time.now
    to_time = Time.now.utc if from_time.utc?
    if num_days != 0 && (to_time - from_time).round > num_days.days.to_i
      from_time.strftime(format)
    else
      time_ago_in_words(from_time, to_time) + " ago"
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
    
  desc %{
    Determine if feed content exceeds a certain length.

    Optional attributes:
    * @ignore_html@:    determines length after removing html and surrounding whitespace

    *Usage:*

    <pre><code>
    <r:feed:if_longer_than length="160">
      ... (<a href="<r:feed:uri />">More</a>)
    </r:feed:if_longer_than>
    </code></pre>
  }
  tag "feed:if_longer_than" do |tag|
    attr = tag.attr.symbolize_keys
    not_to_exceed = attr[:length].to_i
    content = tag.locals.item.content || ""
    if attr[:ignore_html]
      content.gsub!(/<[^>]+>/, '')
      content.gsub!(/\s+/, '')
      content.strip!
    end
    if content.length > not_to_exceed
      tag.expand
    end
  end
end
