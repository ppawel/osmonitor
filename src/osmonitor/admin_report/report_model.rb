module OSMonitor
module AdminReport

class BoundaryStatus < OSMonitor::Status
  def validate
    add_error('boundary_not_closed') if !@entity.closed
  end
end

class AdminReport < OSMonitor::Report
end

end
end
