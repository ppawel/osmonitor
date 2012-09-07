def create_osmonitor_url(road)
  "http://localhost:3000/browse/road/#{road.country}/#{road.ref_prefix + road.ref_number.to_s}"
end
