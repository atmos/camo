require 'rubygems'
require 'json'
require 'base64'
require 'openssl'
require 'rest_client'
require 'addressable/uri'
require 'thin'

require 'test/unit'

module CamoProxyTests
  def config
    { 'key'  => ENV['CAMO_KEY']  || "0x24FEEDFACEDEADBEEFCAFE",
      'host' => ENV['CAMO_HOST'] || "http://localhost:8081" }
  end

  def test_proxy_survives_redirect_without_location
    assert_raise RestClient::ResourceNotFound do
      request('http://localhost:9292')
    end
    response = request('http://media.ebaumsworld.com/picture/Mincemeat/Pimp.jpg')
    assert_equal(200, response.code)
  end

  def test_proxy_valid_image_url
    response = request('http://media.ebaumsworld.com/picture/Mincemeat/Pimp.jpg')
    assert_equal(200, response.code)
  end

  def test_proxy_valid_image_url_with_crazy_subdomain
    response = request('http://27.media.tumblr.com/tumblr_lkp6rdDfRi1qce6mto1_500.jpg')
    assert_equal(200, response.code)
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

  def test_404s_on_10_0_ip_range
    assert_raise RestClient::ResourceNotFound do
      request('http://10.0.0.1/foo.cgi')
    end
  end

  16.upto(31) do |i|
    define_method :"test_404s_on_172_#{i}_ip_range" do
      assert_raise RestClient::ResourceNotFound do
        request("http://172.#{i}.0.1/foo.cgi")
      end
    end
  end

  def test_404s_on_169_254_ip_range
    assert_raise RestClient::ResourceNotFound do
      request('http://169.254.0.1/foo.cgi')
    end
  end

  def test_404s_on_192_168_ip_range
    assert_raise RestClient::ResourceNotFound do
      request('http://192.168.0.1/foo.cgi')
    end
  end

  def test_404s_on_environmental_excludes
    assert_raise RestClient::ResourceNotFound do
      request('http://iphone.internal.example.org/foo.cgi')
    end
  end

  def test_follows_temporary_redirects
    response = request('http://d.pr/i/rr7F+')
    assert_equal(200, response.code)
  end

  def test_request_from_self
    assert_raise RestClient::ResourceNotFound do
      uri = request_uri("http://camo-localhost-test.herokuapp.com")
      response = request( uri )
    end
  end
end

class CamoProxyQueryStringTest < Test::Unit::TestCase
  include CamoProxyTests

  def request_uri(image_url)
    hexdigest = OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest::Digest.new('sha1'), config['key'], image_url)

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
      OpenSSL::Digest::Digest.new('sha1'), config['key'], image_url)
    encoded_image_url = hexenc(image_url)
    "#{config['host']}/#{hexdigest}/#{encoded_image_url}"
  end

  def request(image_url)
    RestClient.get(request_uri(image_url))
  end
end
