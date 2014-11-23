json.array!(@scans) do |scan|
  json.extract! scan, :id, :url, :type, :content, :last_visited
  json.url scan_url(scan, format: :json)
end
