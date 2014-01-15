class ProxyTestServer
  def call(env)
    [302, {"Content-Type" => "image/foo"}, "test"]
  end
end

run ProxyTestServer.new
