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

require 'osmonitor/core/elogger'
require 'osmonitor/core/logging'
require 'osmonitor/core/osm'
require 'osmonitor/core/rgl'
require 'osmonitor/core/road'
require 'osmonitor/core/road_report'
require 'osmonitor/core/wiki'
