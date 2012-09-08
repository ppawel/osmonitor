module OSMonitor

# Responsible for loading input data (e.g. road reference numbers, data for cycleways) to report on.
class InputManager

  def load(report_request)
    result = load_cycleways(report_request) if report_request.report_type == :CYCLEWAY_REPORT.to_s
    result = load_roads(report_request) if report_request.report_type == :ROAD_REPORT.to_s
    result
  end

  protected

  def load_cycleways(report_request)
    result = to_hash_array(CSV.read("#{get_data_path}/cycleways/#{report_request.country}.csv", {:headers => true}))
  end

  def load_roads(report_request)
    result = nil

    if report_request.params.has_key?('ref_prefix')
      result = to_hash_array(CSV.read("#{get_data_path}/road_refs/#{report_request.country}_#{report_request.params['ref_prefix']}.csv", {:headers => true}))
      result.each {|row| row['ref'] = report_request.params['ref_prefix'] + row['ref']}
    elsif report_request.params.has_key?('refs')
      result = report_request.params['refs'].split(',').collect {|ref| Hash['ref', ref]}
    end

    result
  end

  def to_hash_array(result)
    return result if not result.class == 'CSV::Table'
    Array.new(result.collect {|row| row.to_hash})
  end

  def get_data_path
    $osmonitor_home_dir + '/data'
  end
end

end
