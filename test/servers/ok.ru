run lambda { |env|
  path = File.expand_path('../octocat.jpg', __FILE__)
  data = File.read(path)
  [200, {'Content-Type' => 'image/jpeg'}, [data]]
}
