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

class Array
    # define an iterator over each pair of indexes in an array
    def each_pair_index
        (0..(self.length-1)).each do |i|
            ((i+1)..(self.length-1 )).each do |j|
                yield i, j
            end
        end
    end

    # define an iterator over each pair of values in an array for easy reuse
    def each_pair
        self.each_pair_index do |i, j|
            yield self[i], self[j]
            yield self[j], self[i]
        end
    end
end

require 'core/osm'
require 'core/road'
require 'core/road_report'
