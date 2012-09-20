module OSMonitor

class ReportRequest
  attr_accessor :report_type
  attr_accessor :country
  attr_accessor :ids
  attr_accessor :id_prefix
end

class Report
  attr_accessor :report_request
  attr_accessor :statuses

  def initialize
    self.statuses = []
  end

  def add_status(status)
    statuses << status
  end

  def add(report)
    @statuses += report.statuses
  end
end

class Issue
  attr_accessor :name
  attr_accessor :type
  attr_accessor :data

  def initialize(type, name, data)
    self.type = type
    self.name = name
    self.data = data
  end

  def to_s
    "Issue(#{type}, #{name})"
  end
end

class Status
  attr_accessor :entity
  attr_accessor :issues
  attr_accessor :noreport

  def initialize(entity)
    self.entity = entity
    self.issues = []
    self.noreport = false
  end

  def add_error(name, data = {})
    issues << Issue.new(:ERROR, name, data)
  end

  def add_warning(name, data = {})
    issues << Issue.new(:WARNING, name, data)
  end

  def add_info(name, data = {})
    issues << Issue.new(:INFO, name, data)
  end

  def get_issues(type)
    issues.select {|issue| issue.type == type}
  end

  def has_issue_by_name?(name)
    issues.select {|issue| issue.name == name}.size > 0
  end

  def validate
  end

  def color
    return :GREEN if get_issues(:ERROR).empty? and get_issues(:WARNING).empty? and !@noreport
    return :YELLOW if get_issues(:ERROR).empty? and !get_issues(:WARNING).empty? and !@noreport
    return :RED
  end

  def green?
    color == :GREEN
  end
end

end
