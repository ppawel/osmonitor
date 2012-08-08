module OSMonitorLogger
  class <<self
    attr_accessor :log
  end

  @@log = ::EnhancedLogger.new(STDOUT)
  @@log.level = Logger::DEBUG
  self.log = @@log
end

def log_time(name)
  before = Time.now
  if block_given?
    yield
  end
  end_time = Time.now
  OSMonitorLogger.log.debug("#{name} took #{Time.now - before}")
end

require 'core/osm'
require 'core/road'
require 'core/road_report'
