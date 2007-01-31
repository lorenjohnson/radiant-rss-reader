* ABOUT
This is a RadiantCMS extension (originally a behavior by Alessandro Preite Martinez) that
adds some tags to fetch and display RSS feeds. It uses the
'feedparser' module, and it is able to cache the raw feed data
and to only fetch the new feed if it has been modified (using the
If-Modified-Since HTTP header).


* INSTALLATION 
1. Copy this entire rss_reader folder to vendor/extensions in your Radiant installation 
2. Install the FeedParser Ruby module (http://home.gna.org/ruby-feedparser/). It can be copied to the root lib directory 
of your Radiant installation. 
 

* USAGE EXAMPLE
Use it in your page like this (just an example):

 <dl>
 <r:feed:items url="http://some.feed/rss" limit="5">
  <dt><r:feed:link /> - by <r:feed:creator />, <r:feed:date /></dt>
  <dd><r:feed:content /></dd>
 </r:feed:items>
 </dl>


* AUTHOR
Port to Extension:
BJ Clark (bjclark@scidept.com, http://www.scidept.com/) & Loren Johnson (loren@fn-group.com, http://www.fn-group.com)

Original Author: 
Alessandro Preite Martinez (ale@incal.net)