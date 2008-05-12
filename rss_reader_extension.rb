class RssReaderExtension < Radiant::Extension
  version "0.1"
  description "This extension uses the feedtools module to read external rss feeds, cache them, and easily display them in your pages."
  url "http://github.com/lorenjohnson/radiant-rss-reader"
  
  # def activate
  #   Page.send :include, RssReader
  # end
  def activate
    cache_dir = ActionController::Base.page_cache_directory
    Dir.mkdir(cache_dir) unless File.exist?(cache_dir)
    Page.send :include, RssReader
  end
  
  def deactivate
  end
end