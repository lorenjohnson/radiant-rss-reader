* ABOUT
This is a RadiantCMS extension (originally a behavior by Alessandro Preite Martinez) that
adds some tags to fetch and display RSS feeds. It uses the
'ruby-feedparser' module, and it is able to cache the raw feed data
and to only fetch the new feed if it has been modified (using the
If-Modified-Since HTTP header).


* INSTALLATION 
1. Download the .tgz file into the root of your radiant installation.
2. Expand the .tgz file, should put "feedparser.rb and a folder called 'feedparser'" into your /lib/ folder and a folder called rss_reader in /vendors/extensions/ 
 

* USAGE EXAMPLE
Use it in your page like this (just an example):

<dl>
 <r:feed:items url="http://www.somefeed.com/rss limit="5">
  <dt><r:feed:link /> - by <r:feed:creator />, <r:feed:date format="%b %d"/></dt>
  <dd><r:feed:content /></dd>
 </r:feed:items>
 </dl>


* CONTRIBUTORS
Port to Extension:
BJ Clark (bjclark@scidept.com, http://www.scidept.com/) & Loren Johnson (loren@fn-group.com, http://www.fn-group.com)

Modifications:
James MacAulay (jmacaulay@gmail.com, http://jmacaulay.net/)

Original Author: 
Alessandro Preite Martinez (ale@incal.net)

License - Creative Commons Attribution-Share Alike 2.5 License
