require 'rubygems'
require 'json'
require 'base64'
require 'openssl'
require 'rest_client'
require 'addressable/uri'

require 'test/unit'

module CamoProxyTests
  def config
    { 'key'  => ENV['CAMO_KEY']  || "0x24FEEDFACEDEADBEEFCAFE",
      'host' => ENV['CAMO_HOST'] || "http://localhost:8081" }
  end

  def spawn_server(path)
    port = 9292
    config = "test/servers/#{path}.ru"
    host = "localhost:#{port}"
    pid = fork do
      STDOUT.reopen "/dev/null"
      STDERR.reopen "/dev/null"
      exec "rackup", "--port", port.to_s, config
    end
    sleep 2
    begin
      yield host
    ensure
      Process.kill(:TERM, pid)
      Process.wait(pid)
    end
  end

  def test_proxy_localhost_test_server
    spawn_server(:ok) do |host|
      response = RestClient.get("http://#{host}/octocat.jpg")
      assert_equal(200, response.code)

      response = request("http://#{host}/octocat.jpg")
      assert_equal(200, response.code)
    end
  end

  def test_proxy_survives_redirect_without_location
    spawn_server(:redirect_without_location) do |host|
      assert_raise RestClient::ResourceNotFound do
        request("http://#{host}")
      end
    end

    response = request('http://media.ebaumsworld.com/picture/Mincemeat/Pimp.jpg')
    assert_equal(200, response.code)
  end

  def test_follows_https_redirect_for_image_links
    response = request('http://dl.dropbox.com/u/602885/github/soldier-squirrel.jpg')
    assert_equal(200, response.code)
  end

  def test_doesnt_crash_with_non_url_encoded_url
    assert_raise RestClient::ResourceNotFound do
      RestClient.get("#{config['host']}/crashme?url=crash&url=me")
    end
  end

  def test_always_sets_security_headers
    ['/', '/status'].each do |path|
      response = RestClient.get("#{config['host']}#{path}")
      assert_equal "deny", response.headers[:x_frame_options]
      assert_equal "default-src 'none'; img-src data:; style-src 'unsafe-inline'", response.headers[:content_security_policy]
      assert_equal "nosniff", response.headers[:x_content_type_options]
      assert_equal "max-age=31536000; includeSubDomains", response.headers[:strict_transport_security]
    end

    response = request('http://dl.dropbox.com/u/602885/github/soldier-squirrel.jpg')
    assert_equal "deny", response.headers[:x_frame_options]
    assert_equal "default-src 'none'; img-src data:; style-src 'unsafe-inline'", response.headers[:content_security_policy]
    assert_equal "nosniff", response.headers[:x_content_type_options]
    assert_equal "max-age=31536000; includeSubDomains", response.headers[:strict_transport_security]
  end

  def test_proxy_valid_image_url
    response = request('http://media.ebaumsworld.com/picture/Mincemeat/Pimp.jpg')
    assert_equal(200, response.code)
  end

  def test_svg_image_with_delimited_content_type_url
    response = request('https://saucelabs.com/browser-matrix/bootstrap.svg')
    assert_equal(200, response.code)
  end

  def test_png_image_with_delimited_content_type_url
    response = request('http://uploadir.com/u/cm5el1v7')
    assert_equal(200, response.code)
  end

  def test_proxy_valid_image_url_with_crazy_subdomain
    response = request('http://27.media.tumblr.com/tumblr_lkp6rdDfRi1qce6mto1_500.jpg')
    assert_equal(200, response.code)
  end

  def test_strict_image_content_type_checking
    assert_raise RestClient::ResourceNotFound do
      request("http://calm-shore-1799.herokuapp.com/foo.png")
    end
  end

  # QUANTOPIAN CHANGED - added the test below.  Try getting the avatar placeholder image
  # via gravatar, and pass in the same 'accept' header that Chrome would pass in, including
  # 'image/webp'.  Due to our changes in server.coffee, this should result in a png image
  # being returned rather than a webp image.
  def test_webp_disabled
    response = RestClient.get(
      request_uri(
        'https://secure.gravatar.com/avatar/4ab6a20594384864adae340b6abfb65b?' \
        'default=https%3A%2F%2Fs3.amazonaws.com%2Fquantopian-website-assets%2Fempty-profile.png&s=40'
      ),
      {accept: 'image/webp,image/*,*/*;q=0.8'}
    )
    assert_equal(200, response.code)
    assert_equal('image/png', response.headers[:content_type])
  end

  def test_proxy_valid_google_chart_url
    response = request('http://chart.apis.google.com/chart?chs=920x200&chxl=0:%7C2010-08-13%7C2010-09-12%7C2010-10-12%7C2010-11-11%7C1:%7C0%7C0%7C0%7C0%7C0%7C0&chm=B,EBF5FB,0,0,0&chco=008Cd6&chls=3,1,0&chg=8.3,20,1,4&chd=s:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA&chxt=x,y&cht=lc')
    assert_equal(200, response.code)
  end

  def test_proxy_valid_chunked_image_file
    response = request('http://www.igvita.com/posts/12/spdyproxy-diagram.png')
    assert_equal(200, response.code)
    assert_nil(response.headers[:content_length])
  end

  def test_proxy_https_octocat
    response = request('https://octodex.github.com/images/original.png')
    assert_equal(200, response.code)
  end

  def test_proxy_https_gravatar
    response = request('https://1.gravatar.com/avatar/a86224d72ce21cd9f5bee6784d4b06c7')
    assert_equal(200, response.code)
  end

  def test_follows_redirects
    response = request('http://cl.ly/1K0X2Y2F1P0o3z140p0d/boom-headshot.gif')
    assert_equal(200, response.code)
  end

  def test_follows_redirects_formatted_strangely
    response = request('http://cl.ly/DPcp/Screen%20Shot%202012-01-17%20at%203.42.32%20PM.png')
    assert_equal(200, response.code)
  end

  def test_follows_redirects_with_path_only_location_headers
    assert_nothing_raised do
      request('http://blogs.msdn.com/photos/noahric/images/9948044/425x286.aspx')
    end
  end

  def test_forwards_404_with_image
    spawn_server(:not_found) do |host|
      uri = request_uri("http://#{host}/octocat.jpg")
      response = RestClient.get(uri){ |response, request, result| response }
      assert_equal(404, response.code)
      assert_equal("image/jpeg", response.headers[:content_type])
    end
  end

  def test_404s_on_request_error
    spawn_server(:crash_request) do |host|
      assert_raise RestClient::ResourceNotFound do
        request("http://#{host}/cats.png")
      end
    end
  end

  def test_404s_on_infinidirect
    assert_raise RestClient::ResourceNotFound do
      request('http://modeselektor.herokuapp.com/')
    end
  end

  def test_404s_on_urls_without_an_http_host
    assert_raise RestClient::ResourceNotFound do
      request('/picture/Mincemeat/Pimp.jpg')
    end
  end

  def test_404s_on_images_greater_than_5_megabytes
    assert_raise RestClient::ResourceNotFound do
      request('http://apod.nasa.gov/apod/image/0505/larryslookout_spirit_big.jpg')
    end
  end

  def test_404s_on_host_not_found
    assert_raise RestClient::ResourceNotFound do
      request('http://flabergasted.cx')
    end
  end

  def test_404s_on_non_image_content_type
    assert_raise RestClient::ResourceNotFound do
      request('https://github.com/atmos/cinderella/raw/master/bootstrap.sh')
    end
  end

  def test_404s_on_connect_timeout
    assert_raise RestClient::ResourceNotFound do
      request('http://10.0.0.1/foo.cgi')
    end
  end

  def test_404s_on_environmental_excludes
    assert_raise RestClient::ResourceNotFound do
      request('http://iphone.internal.example.org/foo.cgi')
    end
  end

  def test_follows_temporary_redirects
    response = request('http://bit.ly/1l9Fztb')
    assert_equal(200, response.code)
  end

  def test_request_from_self
    assert_raise RestClient::ResourceNotFound do
      uri = request_uri("http://camo-localhost-test.herokuapp.com")
      response = request( uri )
    end
  end

  def test_404s_send_cache_headers
    uri = request_uri("http://example.org/")
    response = RestClient.get(uri){ |response, request, result| response }
    assert_equal(404, response.code)
    assert_equal("0", response.headers[:expires])
    assert_equal("no-cache, no-store, private, must-revalidate", response.headers[:cache_control])
  end
end

class CamoProxyQueryStringTest < Test::Unit::TestCase
  include CamoProxyTests

  def request_uri(image_url)
    hexdigest = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha1'), config['key'], image_url)

    uri = Addressable::URI.parse("#{config['host']}/#{hexdigest}")
    uri.query_values = { 'url' => image_url, 'repo' => '', 'path' => '' }

    uri.to_s
  end

  def request(image_url)
    RestClient.get(request_uri(image_url))
  end
end

class CamoProxyPathTest < Test::Unit::TestCase
  include CamoProxyTests

  def hexenc(image_url)
    image_url.to_enum(:each_byte).map { |byte| "%02x" % byte }.join
  end

  def request_uri(image_url)
    hexdigest = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha1'), config['key'], image_url)
    encoded_image_url = hexenc(image_url)
    "#{config['host']}/#{hexdigest}/#{encoded_image_url}"
  end

  def request(image_url)
    RestClient.get(request_uri(image_url))
  end
end
