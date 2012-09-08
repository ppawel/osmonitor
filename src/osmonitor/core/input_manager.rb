module OSMonitor

# Responsible for loading input data (e.g. road reference numbers, data for cycleways) to report on.
class InputManager

  def load(report_request)
    result = load_cycleways(report_request) if report_request.report_type == :CYCLEWAY_REPORT.to_s
    result = load_road(report_request) if report_request.report_type == :ROAD_REPORT.to_s
    result
  end

  protected

  def load_cycleways(report_request)
    result = CSV.read("#{get_data_path}/cycleways/CR_test.csv", {:headers => true}) if report_request.report_type == :CYCLEWAY_REPORT.to_s
  end

  def load_road(report_request)
    result = CSV.read("../../../data/cycleways/CR_test.csv", {:headers => true}) if params['type'] == 'ROAD_REPORT'
  end

  def get_data_path
    $osmonitor_home_dir + '/data'
  end
end

end
