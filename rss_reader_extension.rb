class RssReaderExtension < Radiant::Extension
  version "0.1"
  description "This extension used the feedtools module to read external rss feeds, cache them, and easily display them in your pages."
  url "http://www.scidept.com/"
  
  # def activate
  #   Page.send :include, RssReader
  # end
  def activate
     RssReader
  end
  
  def deactivate
  end
end