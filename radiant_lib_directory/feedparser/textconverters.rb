# for URI::regexp
require 'uri'
require 'feedparser/html2text-parser'

# This class provides various converters
class String
  # is this text HTML ? search for tags. used by String#text2html
  def html?
    return (self =~ /<p>/) || (self =~ /<\/p>/) || (self =~ /<br>/) || (self =~ /<br\s*(\/)?\s*>/) || (self =~ /<\/a>/) || (self =~ /<img.*>/)
  end

  # returns true if the text contains escaped HTML (with HTML entities). used by String#text2html
  def escaped_html?
    return (self =~ /&lt;img src=/) || (self =~ /&lt;a href=/) || (self =~ /&lt;br(\/| \/|)&gt;/) || (self =~ /&lt;p&gt;/)
  end

  # un-escape HTML in the text. used by String#text2html
  def unescape_html
    {
      '<' => '&lt;',
      '>' => '&gt;',
      "'" => '&apos;',
      '"' => '&quot;',
      '&' => '&amp;',
      "\047" => '&#39;',
      "\046" => '&#038;',
      "\046" => '&#38;'
    }.each do |k, v|
      gsub!(v, k)
    end
    self
  end

  # convert text to HTML
  def text2html
    text = self.clone
    return text if text.html?
    if text.escaped_html?
      return text.unescape_html
    end
    # paragraphs
    text.gsub!(/\A\s*(.*)\Z/m, '<p>\1</p>')
    text.gsub!(/\s*\n(\s*\n)+\s*/, "</p>\n<p>")
    # uris
    text.gsub!(/(#{URI::regexp(['http','ftp','https'])})/,
        '<a href="\1">\1</a>')
    text
  end

  # Remove white space around the text
  def rmWhiteSpace!
    return self.gsub!(/\A\s*/m, '').gsub!(/\s*\Z/m,'')
  end

  # Convert a text in inputenc to a text in UTF8
  # must take care of wrong input locales
  def toUTF8(inputenc)
    if inputenc.downcase != 'utf-8'
      # it is said it is not UTF-8. Ensure it is REALLY not UTF-8
      begin
        if self.unpack('U*').pack('U*') == self
          return self
        end
      rescue
        # do nothing
      end
      begin
        return self.unpack('C*').pack('U*')
      rescue
        return self #failsafe solution. but a dirty one :-)
      end
    else
      return self
    end
  end
end
