require 'test/unit'
require 'rack/urlmap'

path = File.expand_path(File.dirname(__FILE__))
$: << path << File.join(path, 'lib')

require 'rack/esi'

class TestRackESI < Test::Unit::TestCase
  def test_response_passthrough
    mock_app = const([200, {}, ["Hei!"]])
    esi_app = Rack::ESI.new(mock_app)

    assert_same_response(mock_app, esi_app)
  end

  def test_xml_response_passthrough
    mock_app = const([200, {"Content-Type" => "text/xml"}, ["<p>Hei!</p>"]])
    esi_app = Rack::ESI.new(mock_app)

    assert_same_response(mock_app, esi_app)
  end

  def test_respect_for_content_type
    mock_app = const([200, {"Content-Type" => "application/x-y-z"}, ["<esi:include src='/header'/><p>Hei!</p>"]])
    esi_app = Rack::ESI.new(mock_app)

    assert_same_response(mock_app, esi_app)
  end

  def test_include
    app = Rack::URLMap.new({
      "/"       => const([200, {"Content-Type" => "text/xml"}, ["<esi:include src='/header'/>, Index"]]),
      "/header" => const([200, {"Content-Type" => "text/xml"}, ["Header"]])
    })

    esi_app = Rack::ESI.new(app)
    assert_equal ["Header, Index"], esi_app.call("SCRIPT_NAME" => "", "PATH_INFO" => "/")[2]
  end

  def test_include_with_alt
    app = Rack::URLMap.new({
      "/"    => const([200, {"Content-Type" => "text/xml"}, ["<esi:include src='/src' alt='/alt'/>, Index"]]),
      "/src" => const([400, {"Content-Type" => "text/xml"}, ["Src"]]),
      "/alt" => const([200, {"Content-Type" => "text/xml"}, ["Alt"]])
    })

    esi_app = Rack::ESI.new(app)
    assert_equal ["Alt, Index"], esi_app.call("SCRIPT_NAME" => "", "PATH_INFO" => "/")[2]
  end

  def test_include_with_alt_error
    app = Rack::URLMap.new({
      "/"    => const([200, {"Content-Type" => "text/xml"}, ["<esi:include src='/src' alt='/alt'/>, Index"]]),
      "/src" => const([400, {"Content-Type" => "text/xml"}, ["Src"]]),
      "/alt" => const([400, {"Content-Type" => "text/xml"}, ["Alt"]])
    })

    esi_app = Rack::ESI.new(app)
    assert_raise RuntimeError do
      esi_app.call("SCRIPT_NAME" => "", "PATH_INFO" => "/")
    end
  end

  def test_remove
    mock_app = const([200, {"Content-Type" => "text/xml"}, ["<p>Hei! <esi:remove>Hei! </esi:remove>Hei!</p>"]])
    esi_app = Rack::ESI.new(mock_app)
    assert_equal ["<p>Hei! Hei!</p>"], esi_app.call("SCRIPT_NAME" => "", "PATH_INFO" => "/")[2]
  end

  def test_remove_xmlns
    mock_app = const([200, {"Content-Type" => "text/xml"}, ["<html xmlns:esi=\"esi\" lang=\"en\"><p>Hei!</p><esi:remove>removed</esi:remove>"]])

    esi_app = Rack::ESI.new(mock_app)
    assert_equal ["<html lang=\"en\"><p>Hei!</p>"], esi_app.call("SCRIPT_NAME" => "", "PATH_INFO" => "/")[2]
  end

  def test_comment
    mock_app = const([200, {"Content-Type" => "text/xml"}, ["<p>(<esi:comment text='*'/>)</p>"]])

    esi_app = Rack::ESI.new(mock_app)
    assert_equal ["<p>()</p>"], esi_app.call("SCRIPT_NAME" => "", "PATH_INFO" => "/")[2]
  end

  def test_setting_of_content_length
    mock_app = const([200, {"Content-Type" => "text/html"}, ["Osameli. <esi:comment text='*'/>"]])

    esi_app = Rack::ESI.new(mock_app)

    response = esi_app.call("SCRIPT_NAME" => "", "PATH_INFO" => "/")

    assert_equal("9", response[1]["Content-Length"])
  end

  private

  def const(value)
    lambda { |*_| value }
  end

  def assert_same_response(a, b)
    x = a.call({})
    y = b.call({})

    assert_equal(x,           y)
    assert_equal(x.object_id, y.object_id)
  end
end
