# ABOUT
This is a RadiantCMS extension (originally a behavior by Alessandro Preite Martinez) that
adds some tags to fetch and display RSS feeds. It uses the
'ruby-feedparser' module, and it is able to cache the raw feed data
and to only fetch the new feed if it has been modified (using the
If-Modified-Since HTTP header).


# INSTALLATION

## via Git

    cd RADIANT_APP_ROOT
    git clone git://github.com/lorenjohnson/radiant-rss-reader.git vendor/extensions/rss_reader

## via Git (as submodule)
  
    cd RADIANT_APP_ROOT
    git submodule add git://github.com/lorenjohnson/radiant-rss-reader.git vendor/extensions/rss_reader

...then `git submodule init` and `git submodule update` as necessary.

## via tarball

Download the tarball from http://github.com/lorenjohnson/radiant-rss-reader/tarball/master into `RADIANT_APP_ROOT/vendor/extentions`, then:

    cd RADIANT_APP_ROOT/vendor/extentions
    tar xvzf lorenjohnson-radiant-rss-reader.tgz
    mv lorenjohnson-radiant-rss-reader rss_reader

# USAGE EXAMPLE
Use it in your page like this (just an example):

    <dl>
     <r:feed:items url="http://www.somefeed.com/rss" limit="5">
      <dt><r:feed:link /> - by <r:feed:creator />, <r:feed:date format="%b %d"/></dt>
      <dd><r:feed:content /></dd>
     </r:feed:items>
    </dl>
    
You can also order by some feed entry attribute other than the date:

    <ul>

      <r:feed:items
          url="http://feeds.boingboing.net/boingboing/iBag" 
          order="creator ASC">

        <li><r:feed:link /></li>

      </r:feed:items>

    </ul>
    
And you can do headers to mark off sections:

    <ul>

      <r:feed:items
          url="http://feeds.boingboing.net/boingboing/iBag" 
          order="creator ASC">

        <r:feed:header for="creator">
          <h2><r:feed:creator /></h2>
        </r:feed:header>

        <li><r:feed:link /></li>

      </r:feed:items>

    </ul>

You can sort items and group headers by date, title, content, creator, or link (i.e. the URL of the item). There are more things you can do, which are documented in `rss_reader.rb`.

# CONTRIBUTORS

Original Author:

* Alessandro Preite Martinez (ale@incal.net)

Port to Extension:

* BJ Clark (bjclark@scidept.com, http://www.scidept.com/)
* Loren Johnson (loren@fn-group.com, http://www.fn-group.com)

Modifications:

* James MacAulay (jmacaulay@gmail.com, http://jmacaulay.net/)
* Michael Hale (mikehale@gmail.com, http://michaelahale.com/)
* Bryan Liles (iam@smartic.us, http://smartic.us/)

License - Creative Commons Attribution-Share Alike 2.5 License
