def create_osmonitor_url(report, road)
  "http://localhost:3000/browse/#{report.report_request.report_type.downcase}/#{road.country}/#{road.ref_prefix + road.ref_number.to_s}"
end
