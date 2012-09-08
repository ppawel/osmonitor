require 'osmonitor/core'
require 'erb'
require 'pg'

module OSMonitor
module CyclewayReport

class ReportManager < OSMonitor::RoadReport::ReportManager
  def create_road_manager(conn)
    RoadManager.new(conn)
  end

  def create_report_instance
    RoadReport.new
  end

  def create_status_instance(road)
    RoadStatus.new(road)
  end
end

end
end
