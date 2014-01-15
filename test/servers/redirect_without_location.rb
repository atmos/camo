require 'thin'

class ProxyTestServer
  def call(env)
    [302, {"Content-Type" => "image/foo"}, "test"]
  end
end

Thin::Server.start('127.0.0.1', 9292) do
	run ProxyTestServer.new
end