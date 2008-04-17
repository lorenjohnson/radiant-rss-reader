# =Ruby-feedparser - ATOM/RSS feed parser for Ruby
# License:: Ruby's license (see the LICENSE file) or GNU GPL, at your option.
# Website::http://home.gna.org/ruby-feedparser/
#
# ==Introduction
#
# Ruby-Feedparser is an RSS and Atom parser for Ruby.
# Ruby-feedparser is :
# * based on REXML
# * built for robustness : most feeds are not valid, a parser can't ignore that
# * fully unit-tested
# * easy to use (it can output text or HTML easily)
#
# ==Example
#  require 'net/http'
#  require 'feedparser'
#  require 'uri'
#  s = Net::HTTP::get URI::parse('http://rss.slashdot.org/Slashdot/slashdot')
#  f = FeedParser::Feed::new(s)
#  f.title
#  => "Slashdot"
#  f.items.each { |i| puts i.title }
#  [...]
#  require 'feedparser/html-output'
#  f.items.each { |i| puts i.to_html }
#

require 'feedparser/feedparser'
