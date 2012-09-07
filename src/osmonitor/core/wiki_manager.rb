require 'config'
require 'media_wiki'

# Responsible for:
# * interaction with a MediaWiki instance (can fetch/update pages)
# * processing (parsing, replacing) OSMonitor segments in a wiki page
#
class WikiManager
  attr_accessor :gateway

  def initialize
    self.gateway = MediaWiki::Gateway.new('https://wiki.openstreetmap.org/w/api.php')
  end

  def login(user, password)
    @gateway.login(user, password)
  end

  def get_osmonitor_page(input_page)
    page = OSMonitorWikiPage.new
    page.text = @gateway.get(input_page)
    old_page_text = page.text.dup

    old_page_text.scan(/((<\!\-\- OSMonitor ([^\s]+)(.*?)\-\->).*?(<\!\-\- OSMonitor \/\3 \-\->))/mi) do |match|
      segment = OSMonitorWikiPageSegment.new
      segment.all = match[0]
      segment.beginning = match[1]
      segment.ending = match[4]
      segment.type = match[2]
      segment.params = parse_params(match[3])

      page.segments << segment
    end

    page
  end

  def replace_segment(page, segment, new_text)
    page.text[segment.all] = "#{segment.beginning}#{new_text}#{segment.ending}"
  end

  def save_page(page, page_name)
    @gateway.create(page_name, page.text, :overwrite => true, :summary => 'Automated')
  end

  def parse_params(params_string)
    Hash[params_string.scan(/([^\s\=]+)\=([^\s\=]+)/)]
  end
end

class OSMonitorWikiPage
  attr_accessor :text
  attr_accessor :segments

  def initialize
    self.segments = []
  end

  def get_segments(type)
    @segments.select {|segment| segment.type == type}
  end
end


# Holds information for an OSMonitor segment in a wiki page.
class OSMonitorWikiPageSegment
  attr_accessor :all
  attr_accessor :beginning
  attr_accessor :ending
  attr_accessor :type
  attr_accessor :params
end
