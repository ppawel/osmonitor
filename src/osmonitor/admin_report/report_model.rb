module OSMonitor
module AdminReport

class BoundaryStatus < OSMonitor::Status
  def validate
    add_error('no_relation') if !@entity.relation
    add_error('boundary_not_closed') if @entity.relation and !@entity.closed
  end
end

class AdminReport < OSMonitor::Report
end

end
end
