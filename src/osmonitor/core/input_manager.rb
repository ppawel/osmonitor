require 'csv'

module OSMonitor

# Responsible for loading input data (e.g. road reference numbers, data for cycleways) to report on.
class InputManager

  def load(report_request)
    result = load_admin(report_request) if report_request.report_type == :ADMIN_REPORT.to_s
    result = load_cycleways(report_request) if report_request.report_type == :CYCLEWAY_REPORT.to_s
    result = load_roads(report_request) if report_request.report_type == :ROAD_REPORT.to_s
    result
  end

  protected

  def load_admin(report_request)
    to_hash_array(CSV.read("#{get_data_path}/admin/#{report_request.country}.csv", {:headers => true, :encoding => 'UTF-8'}))
  end

  def load_cycleways(report_request)
    to_hash_array(CSV.read("#{get_data_path}/cycleways/#{report_request.country}.csv", {:headers => true}))
  end

  def load_roads(report_request)
    result = to_hash_array(CSV.read("#{get_data_path}/road_refs/#{report_request.country}.csv", {:headers => true}))

    if report_request.id_prefix
      result = filter_by_prefix(result, report_request.id_prefix)
    elsif report_request.ids
      result = filter_by_refs(result, report_request.ids.split(','))
    end

    result
  end

  def filter_by_prefix(all_input, prefix)
    all_input.select {|input| input['id'].start_with?(prefix)}
  end

  def filter_by_refs(all_input, refs)
    all_input.select {|input| refs.include?(input['id'])}
  end

  def to_hash_array(result)
    return result if result.class.to_s != 'CSV::Table'
    Array.new(result.collect {|row| row.to_hash})
  end

  def get_data_path
    $osmonitor_home_dir + '/data'
  end
end

end
