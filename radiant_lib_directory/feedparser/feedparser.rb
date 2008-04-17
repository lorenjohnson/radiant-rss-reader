require 'rexml/document'
require 'time'
require 'feedparser/textconverters'
require 'feedparser/rexml_patch'
require 'base64'

module FeedParser

  class UnknownFeedTypeException < RuntimeError
  end

  # an RSS/Atom feed
  class Feed
    attr_reader :type, :title, :link, :description, :creator, :encoding, :items

    # REXML::Element for this feed.
    attr_reader :xml

    # parse str to build a Feed
    def initialize(str = nil)
      parse(str) if str
    end

    # Determines all the fields using a string containing an
    # XML document
    def parse(str)
      # Dirty hack: some feeds contain the & char. It must be changed to &amp;
      str.gsub!(/&(\s+)/, '&amp;\1')
      doc = REXML::Document.new(str)
      @xml = doc.root
      # get feed info
      @encoding = doc.encoding
      @title,@link,@description,@creator = nil
      @items = []
      if doc.root.elements['channel'] || doc.root.elements['rss:channel']
        @type = "rss"
        # We have a RSS feed!
        # Title
        if (e = doc.root.elements['channel/title'] ||
          doc.root.elements['rss:channel/rss:title']) && e.text
          @title = e.text.toUTF8(@encoding).rmWhiteSpace!
        end
        # Link
        if (e = doc.root.elements['channel/link'] ||
            doc.root.elements['rss:channel/rss:link']) && e.text
          @link = e.text.rmWhiteSpace!
        end
        # Description
        if (e = doc.root.elements['channel/description'] || 
            doc.root.elements['rss:channel/rss:description']) && e.text
          @description = e.text.toUTF8(@encoding).rmWhiteSpace!
        end
        # Creator
        if ((e = doc.root.elements['channel/dc:creator']) && e.text) ||
            ((e = doc.root.elements['channel/author'] ||
            doc.root.elements['rss:channel/rss:author']) && e.text)
          @creator = e.text.toUTF8(@encoding).rmWhiteSpace!
        end
        # Items
        if doc.root.elements['channel/item']
          query = 'channel/item'
        elsif doc.root.elements['item']
          query = 'item'
        elsif doc.root.elements['rss:channel/rss:item']
          query = 'rss:channel/rss:item'
        else
          query = 'rss:item'
        end
        doc.root.each_element(query) { |e| @items << RSSItem::new(e, self) }

      elsif doc.root.elements['/feed']
        # We have an ATOM feed!
        @type = "atom"
        # Title
        if (e = doc.root.elements['/feed/title']) && e.text
          @title = e.text.toUTF8(@encoding).rmWhiteSpace!
        end
        # Link
        doc.root.each_element('/feed/link') do |e|
          if e.attribute('type') and (
              e.attribute('type').value == 'text/html' or
              e.attribute('type').value == 'application/xhtml' or
              e.attribute('type').value == 'application/xhtml+xml')
            if (h = e.attribute('href')) && h
              @link = h.value.rmWhiteSpace!
            end
          end
        end
        # Description
        if e = doc.root.elements['/feed/info']
          e = e.elements['div'] || e
          @description = e.to_s.toUTF8(@encoding).rmWhiteSpace!
        end
        # Items
        doc.root.each_element('/feed/entry') do |e|
           @items << AtomItem::new(e, self)
        end
      else
        raise UnknownFeedTypeException::new
      end
    end

    def to_s
      s  = ''
      s += "Type: #{@type}\n"
      s += "Encoding: #{@encoding}\n"
      s += "Title: #{@title}\n"
      s += "Link: #{@link}\n"
      s += "Description: #{@description}\n"
      s += "Creator: #{@creator}\n"
      s += "\n"
      @items.each { |i| s += i.to_s }
      s
    end
  end

  # an Item from a feed
  class FeedItem
    attr_accessor :title, :link, :content, :date, :creator, :subject,
                  :category, :cacheditem

    attr_reader :feed

    # REXML::Element for this item
    attr_reader :xml

    def initialize(item = nil, feed = nil)
      @xml = item
      @feed = feed
      @title, @link, @content, @date, @creator, @subject, @category = nil
      parse(item) if item
    end

    def parse(item)
      raise "parse() should be implemented by subclasses!"
    end

    def to_s
      s = "--------------------------------\n" +
        "Title: #{@title}\nLink: #{@link}\n" +
        "Date: #{@date.to_s}\nCreator: #{@creator}\n" +
        "Subject: #{@subject}\nCategory: #{@category}\nContent:\n#{content}\n"
      if defined?(@enclosures) and @enclosures.length > 0
        s2 = "Enclosures:\n"
        @enclosures.each do |e|
          s2 += e.join(' ') + "\n"
        end
        s += s2
      end
      return s
    end
  end

  class RSSItem < FeedItem

    # The item's enclosures childs. An array of (url, length, type) triplets.
    attr_accessor :enclosures

    def parse(item)
      # Title. If no title, use the pubDate as fallback.
      if ((e = item.elements['title'] || item.elements['rss:title']) &&
          e.text)  ||
          ((e = item.elements['pubDate'] || item.elements['rss:pubDate']) &&
           e.text)
        @title = e.text.toUTF8(@feed.encoding).rmWhiteSpace!
      end
      # Link
      if ((e = item.elements['link'] || item.elements['rss:link']) && e.text)||
          (e = item.elements['guid'] || item.elements['rss:guid'] and
          not (e.attribute('isPermaLink') and
          e.attribute('isPermaLink').value == 'false'))
        @link = e.text.rmWhiteSpace!
      end
      # Content
      if (e = item.elements['content:encoded']) ||
        (e = item.elements['description'] || item.elements['rss:description'])
        @content = FeedParser::getcontent(e, @feed)
      end
      # Date
      if e = item.elements['dc:date'] || item.elements['pubDate'] || 
          item.elements['rss:pubDate']
        begin
          @date = Time::xmlschema(e.text)
        rescue
          begin
            @date = Time::rfc2822(e.text)
          rescue
            begin
              @date = Time::parse(e.text)
            rescue
              @date = nil
            end
          end
        end
      end
      # Creator
      @creator = @feed.creator
      if (e = item.elements['dc:creator'] || item.elements['author'] ||
          item.elements['rss:author']) && e.text
        @creator = e.text.toUTF8(@feed.encoding).rmWhiteSpace!
      end
      # Subject
      if (e = item.elements['dc:subject']) && e.text
        @subject = e.text.toUTF8(@feed.encoding).rmWhiteSpace!
      end
      # Category
      if (e = item.elements['dc:category'] || item.elements['category'] ||
          item.elements['rss:category']) && e.text
        @category = e.text.toUTF8(@feed.encoding).rmWhiteSpace!
      end
      # Enclosures
      @enclosures = []
      item.each_element('enclosure') do |e|
        url = e.attribute('url').value if e.attribute('url')
        length = e.attribute('length').value if e.attribute('length')
        type = e.attribute('type').value if e.attribute('type')
        @enclosures << [ url, length, type ]
      end
    end
  end

  class AtomItem < FeedItem
    def parse(item)
      # Title
      if (e = item.elements['title']) && e.text
        @title = e.text.toUTF8(@feed.encoding).rmWhiteSpace!
      end
      # Link
      item.each_element('link') do |e|
        if e.attribute('type') and (
            e.attribute('type').value == 'text/html' or
            e.attribute('type').value == 'application/xhtml' or
            e.attribute('type').value == 'application/xhtml+xml')
          if (h = e.attribute('href')) && h.value
            @link = h.value
          end
        end
      end
      # Content
      if e = item.elements['content'] || item.elements['summary']
        if (e.attribute('mode') and e.attribute('mode').value == 'escaped') &&
          e.text
          @content = e.text.toUTF8(@feed.encoding).rmWhiteSpace!
        else
          @content = FeedParser::getcontent(e, @feed)
        end
      end
      # Date
      if (e = item.elements['issued'] || e = item.elements['created']) && e.text
        begin
          @date = Time::xmlschema(e.text)
        rescue
          begin
            @date = Time::rfc2822(e.text)
          rescue
            begin
              @date = Time::parse(e.text)
            rescue
              @date = nil
            end
          end
        end
      end
      # Creator
      @creator = @feed.creator
      if (e = item.elements['author/name']) && e.text
        @creator = e.text.toUTF8(@feed.encoding).rmWhiteSpace!
      end
    end
  end

  def FeedParser::getcontent(e, feed = nil)
    encoding = feed ? feed.encoding : 'utf-8'
    children = e.children.reject do |i|
      i.class == REXML::Text and i.to_s.chomp == ''
    end
    if children.length > 1
      s = ''
      children.each { |c| s += c.to_s }
      return s.toUTF8(encoding).rmWhiteSpace!.text2html
    elsif children.length == 1
      c = children[0]
      if c.class == REXML::Text
        return e.text.toUTF8(encoding).rmWhiteSpace!.text2html
      else
        if c.class == REXML::CData
          return c.to_s.toUTF8(encoding).rmWhiteSpace!.text2html
        elsif c.text
          return c.text.toUTF8(encoding).text2html
        end
      end
    end
  end
end
