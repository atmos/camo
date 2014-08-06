require 'rubygems'
require 'json'
require 'test/unit'

class CamoAppTest < Test::Unit::TestCase
  def test_heroku_app_json
    app_file = File.expand_path("../../app.json", __FILE__)
    assert_nothing_raised do
      JSON.parse(File.read(app_file))
    end
  end
end
