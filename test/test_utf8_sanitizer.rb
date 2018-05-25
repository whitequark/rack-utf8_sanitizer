# encoding:ascii-8bit

require 'bacon/colored_output'
require 'rack/utf8_sanitizer'

describe Rack::UTF8Sanitizer do
  before do
    @app = Rack::UTF8Sanitizer.new(-> env { env })
  end

  shared :does_sanitize_plain do
    it "sanitizes plaintext entity (HTTP_USER_AGENT)" do
      env    = @app.({ "HTTP_USER_AGENT" => @plain_input })
      result = env["HTTP_USER_AGENT"]

      result.encoding.should == Encoding::UTF_8
      result.should.be.valid_encoding
    end
  end

  shared :does_sanitize_uri do
    it "sanitizes URI-like entity (REQUEST_PATH)" do
      env    = @app.({ "REQUEST_PATH" => @uri_input })
      result = env["REQUEST_PATH"]

      result.encoding.should == Encoding::US_ASCII
      result.should.be.valid_encoding
    end
  end

  describe "with invalid host input" do
    it "sanitizes host entity (SERVER_NAME)" do
      host   = "host\xD0".force_encoding('UTF-8')
      env    = @app.({ "SERVER_NAME" => host })
      result = env["SERVER_NAME"]

      result.encoding.should == Encoding::US_ASCII
      result.should.be.valid_encoding
    end
  end

  describe "with invalid UTF-8 input" do
    before do
      @plain_input = "foo\xe0".force_encoding('UTF-8')
      @uri_input   = "http://bar/foo%E0".force_encoding('UTF-8')
    end

    behaves_like :does_sanitize_plain
    behaves_like :does_sanitize_uri
  end

  describe "with invalid, incorrectly percent-encoded UTF-8 URI input" do
    before do
      @uri_input   = "http://bar/foo%E0\xe0".force_encoding('UTF-8')
    end

    behaves_like :does_sanitize_uri
  end

  describe "with invalid ASCII-8BIT input" do
    before do
      @plain_input = "foo\xe0"
      @uri_input   = "http://bar/foo%E0"
    end

    behaves_like :does_sanitize_plain
    behaves_like :does_sanitize_uri
  end

  describe "with invalid, incorrectly percent-encoded ASCII-8BIT URI input" do
    before do
      @uri_input   = "http://bar/foo%E0\xe0"
    end

    behaves_like :does_sanitize_uri
  end

  shared :identity_plain do
    it "does not change plaintext entity (HTTP_USER_AGENT)" do
      env    = @app.({ "HTTP_USER_AGENT" => @plain_input })
      result = env["HTTP_USER_AGENT"]

      result.encoding.should == Encoding::UTF_8
      result.should.be.valid_encoding
      result.should == @plain_input
    end
  end

  shared :identity_uri do
    it "does not change URI-like entity (REQUEST_PATH)" do
      env    = @app.({ "REQUEST_PATH" => @uri_input })
      result = env["REQUEST_PATH"]

      result.encoding.should == Encoding::US_ASCII
      result.should.be.valid_encoding
      result.should == @uri_input
    end
  end

  describe "with valid UTF-8 input" do
    before do
      @plain_input = "foo bar лол".force_encoding('UTF-8')
      @uri_input   = "http://bar/foo+bar+%D0%BB%D0%BE%D0%BB".force_encoding('UTF-8')
    end

    behaves_like :identity_plain
    behaves_like :identity_uri

    describe "with URI characters from reserved range" do
      before do
        @uri_input   = "http://bar/foo+%2F%3A+bar+%D0%BB%D0%BE%D0%BB".force_encoding('UTF-8')
      end

      behaves_like :identity_uri
    end
  end

  describe "with valid, not percent-encoded UTF-8 URI input" do
    before do
      @uri_input   = "http://bar/foo+bar+лол".force_encoding('UTF-8')
    end

    it "does not change URI-like entity (REQUEST_PATH)" do
      env    = @app.({ "REQUEST_PATH" => @uri_input })
      result = env["REQUEST_PATH"]

      result.encoding.should == Encoding::US_ASCII
      result.should.be.valid_encoding
      result.should == URI.encode(@uri_input)
    end
  end

  describe "with valid ASCII-8BIT input" do
    before do
      @plain_input = "bar baz"
      @uri_input   = "http://bar/bar+baz"
    end

    behaves_like :identity_plain
    behaves_like :identity_uri

    describe "with URI characters from reserved range" do
      before do
        @uri_input   = "http://bar/foo+%2F%3A+bar+%D0%BB%D0%BE%D0%BB"
      end

      behaves_like :identity_uri
    end
  end

  describe "with frozen strings" do
    before do
      @plain_input = "bar baz".freeze
      @uri_input   = "http://bar/bar+baz".freeze
    end

    it "preserves the frozen? status of input" do
      env  = @app.({ "HTTP_USER_AGENT" => @plain_input,
                     "REQUEST_PATH" => @uri_input })

      env["HTTP_USER_AGENT"].should.be.frozen
      env["REQUEST_PATH"].should.be.frozen
    end
  end

  describe "with symbols in the env" do
    before do
      @uri_input = "http://bar/foo%E0\xe0".force_encoding('UTF-8')
    end

    it "sanitizes REQUEST_PATH with invalid UTF-8 URI input" do
      env  = @app.({ :requested_at => "2014-07-22",
                     "REQUEST_PATH" => @uri_input })

      result = env["REQUEST_PATH"]

      result.encoding.should == Encoding::US_ASCII
      result.should.be.valid_encoding
    end
  end

  describe "with form data" do
    def request_env
      @plain_input = "foo bar лол".force_encoding('UTF-8')
      {
         "REQUEST_METHOD" => "POST",
         "CONTENT_TYPE" => "application/x-www-form-urlencoded;foo=bar",
         "HTTP_USER_AGENT" => @plain_input,
         "rack.input" => @rack_input,
      }
    end

    def sanitize_form_data(request_env = request_env())
      @uri_input = "http://bar/foo+%2F%3A+bar+%D0%BB%D0%BE%D0%BB".force_encoding('UTF-8')
      @response_env = @app.(request_env)
      sanitized_input = @response_env['rack.input'].read

      yield sanitized_input if block_given?

      @response_env['rack.input'].rewind
      behaves_like :does_sanitize_plain
      behaves_like :does_sanitize_uri
      behaves_like :identity_plain
      behaves_like :identity_uri
      @response_env['rack.input'].close
    end

    it "sanitizes StringIO rack.input" do
      input = "foo=bla&quux=bar"
      @rack_input = StringIO.new input

      sanitize_form_data do |sanitized_input|
        sanitized_input.encoding.should == Encoding::UTF_8
        sanitized_input.should.be.valid_encoding
        sanitized_input.should == input
      end
    end

    it "sanitizes StringIO rack.input on GET" do
      input = "foo=bla&quux=bar"
      @rack_input = StringIO.new input

      sanitize_form_data(request_env.merge("REQUEST_METHOD" => "GET")) do |sanitized_input|
        sanitized_input.encoding.should == Encoding::UTF_8
        sanitized_input.should.be.valid_encoding
        sanitized_input.should == input
      end
    end

    it "sanitizes StringIO rack.input with bad encoding" do
      input =  "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      sanitize_form_data do |sanitized_input|
        sanitized_input.encoding.should == Encoding::UTF_8
        sanitized_input.should.be.valid_encoding
        sanitized_input.should != input
      end
    end

    it "strip UTF-8 BOM from StringIO rack.input" do
      input = %(\xef\xbb\xbf{"Hello": "World"})
      @rack_input = StringIO.new input

      sanitize_form_data(request_env.merge("CONTENT_TYPE" => "application/json")) do |sanitized_input|
        sanitized_input.encoding.should == Encoding::UTF_8
        sanitized_input.should.be.valid_encoding
        sanitized_input.should == '{"Hello": "World"}'
      end
    end

    it "sanitizes StringIO rack.input with form encoded bad encoding" do
      input = "foo=bla&foo=baz&quux%ED=bar%ED"
      @rack_input = StringIO.new input

      sanitize_form_data do |sanitized_input|
        # URI.decode_www_form does some encoding magic
        sanitized_input.split("&").each do |pair|
          pair.split("=", 2).each do |component|
            decoded = URI.decode_www_form_component(component)
            decoded.should.be.valid_encoding
          end
        end
        sanitized_input.should != input
      end
    end

    it "sanitizes non-StringIO rack.input" do
      require 'rack/rewindable_input'
      input = "foo=bla&quux=bar"
      @rack_input = Rack::RewindableInput.new(StringIO.new(input))

      sanitize_form_data do |sanitized_input|
        sanitized_input.encoding.should == Encoding::UTF_8
        sanitized_input.should.be.valid_encoding
        sanitized_input.should == input
      end
    end

    it "sanitizes non-StringIO rack.input with bad encoding" do
      require 'rack/rewindable_input'
      input =  "foo=bla&quux=bar\xED"
      @rack_input = Rack::RewindableInput.new(StringIO.new(input))

      sanitize_form_data do |sanitized_input|
        sanitized_input.encoding.should == Encoding::UTF_8
        sanitized_input.should.be.valid_encoding
        sanitized_input.should != input
      end
    end

    it "does not sanitize the rack body if there is no CONTENT_TYPE" do
      input =  "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      env = request_env.update('CONTENT_TYPE' => nil)
      sanitize_form_data(env) do |sanitized_input|
        sanitized_input.encoding.should == Encoding::ASCII_8BIT
        sanitized_input.should.be.valid_encoding
        sanitized_input.should == input
      end
    end

    it "does not sanitize the rack body if there is empty CONTENT_TYPE" do
      input =  "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      env = request_env.update('CONTENT_TYPE' => '')
      sanitize_form_data(env) do |sanitized_input|
        sanitized_input.encoding.should == Encoding::ASCII_8BIT
        sanitized_input.should.be.valid_encoding
        sanitized_input.should == input
      end
    end

    it "adjusts content-length when replacing input" do
      input =  "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      env = request_env.update("CONTENT_LENGTH" => input.bytesize)
      sanitize_form_data(env) do |sanitized_input|
        sanitized_input.bytesize.should != input.bytesize
        @response_env["CONTENT_LENGTH"].should == sanitized_input.bytesize.to_s
      end
    end
  end

  describe "with custom content-type" do
    def request_env
      {
          "REQUEST_METHOD" => "GET",
          "CONTENT_TYPE" => "application/json",
          "HTTP_COOKIE" => @cookie,
          "rack.input" => StringIO.new,
      }
    end

    it "sanitizes bad http cookie" do
      @cookie = "foo=bla; quux=bar\xED"
      response_env = @app.(request_env)
      response_env['HTTP_COOKIE'].should != @cookie
      response_env['HTTP_COOKIE'].should == 'foo=bla; quux=bar%EF%BF%BD'
    end

    it "does not change ok http cookie" do
      @cookie = "foo=bla; quux=bar"
      response_env = @app.(request_env)
      response_env['HTTP_COOKIE'].should == @cookie

      @cookie = "foo=b%3bla; quux=b%20a%20r"
      response_env = @app.(request_env)
      response_env['HTTP_COOKIE'].should == @cookie
    end
  end

  describe "with custom content-type" do
    def request_env
      @plain_input = "foo bar лол".force_encoding('UTF-8')
      {
          "REQUEST_METHOD" => "POST",
          "CONTENT_TYPE" => "application/vnd.api+json",
          "HTTP_USER_AGENT" => @plain_input,
          "rack.input" => @rack_input,
      }
    end

    def sanitize_data(request_env = request_env())
      @uri_input = "http://bar/foo+%2F%3A+bar+%D0%BB%D0%BE%D0%BB".force_encoding('UTF-8')
      @response_env = @app.(request_env)
      sanitized_input = @response_env['rack.input'].read

      yield sanitized_input if block_given?
    end

    it "does not sanitize custom content-type by default" do
      input =  "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      env = request_env
      sanitize_data(env) do |sanitized_input|
        sanitized_input.encoding.should == Encoding::ASCII_8BIT
        sanitized_input.should.be.valid_encoding
        sanitized_input.should == input
      end
    end

    it "sanitizes custom content-type if additional_content_types given" do
      @app = Rack::UTF8Sanitizer.new(-> env { env }, additional_content_types: ["application/vnd.api+json"])
      input =  "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      env = request_env
      sanitize_data(env) do |sanitized_input|
        sanitized_input.encoding.should == Encoding::UTF_8
        sanitized_input.should.be.valid_encoding
        sanitized_input.should != input
      end
    end

    it "sanitizes default content-type if additional_content_types given" do
      @app = Rack::UTF8Sanitizer.new(-> env { env }, additional_content_types: ["application/vnd.api+json"])
      input =  "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      env = request_env.update('CONTENT_TYPE' => 'application/json')
      sanitize_data(env) do |sanitized_input|
        sanitized_input.encoding.should == Encoding::UTF_8
        sanitized_input.should.be.valid_encoding
        sanitized_input.should != input
      end
    end

    it "sanitizes custom content-type if sanitizable_content_types given" do
      @app = Rack::UTF8Sanitizer.new(-> env { env }, sanitizable_content_types: ["application/vnd.api+json"])
      input =  "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      env = request_env
      sanitize_data(env) do |sanitized_input|
        sanitized_input.encoding.should == Encoding::UTF_8
        sanitized_input.should.be.valid_encoding
        sanitized_input.should != input
      end
    end

    it "does not sanitize default content-type if sanitizable_content_types does not include it" do
      @app = Rack::UTF8Sanitizer.new(-> env { env }, sanitizable_content_types: ["application/vnd.api+json"])
      input =  "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      env = request_env.update('CONTENT_TYPE' => 'application/json')
      sanitize_data(env) do |sanitized_input|
        sanitized_input.encoding.should == Encoding::ASCII_8BIT
        sanitized_input.should.be.valid_encoding
        sanitized_input.should == input
      end
    end
  end

  describe "with only and/or except options" do
    before do
      @plain_input = "foo\xe0".force_encoding('UTF-8')
    end

    def request_env
      {
          "REQUEST_METHOD" => "POST",
          "CONTENT_TYPE" => "application/json",
          "HTTP_USER_AGENT" => @plain_input,
          "HTTP_CUSTOM_HEADER" => @plain_input,
          "rack.input" => @rack_input,
      }
    end

    def sanitize_data(request_env = request_env())
      @response_env = @app.(request_env)
    end

    it 'skips unless in only' do
      @app = Rack::UTF8Sanitizer.new(
        -> env { env },
        only: ['HTTP_CUSTOM_HEADER']
      )
      @rack_input = StringIO.new('{}')

      sanitize_data
      @response_env['HTTP_CUSTOM_HEADER'].should != @plain_input
      @response_env['HTTP_USER_AGENT'].should == @plain_input
    end

    it 'skips if in except' do
      @app = Rack::UTF8Sanitizer.new(
        -> env { env },
        except: ['HTTP_CUSTOM_HEADER']
      )
      @rack_input = StringIO.new('{}')

      sanitize_data
      @response_env['HTTP_CUSTOM_HEADER'].should == @plain_input
      @response_env['HTTP_USER_AGENT'].should != @plain_input
    end

    it 'works with regular expressions' do
      @app = Rack::UTF8Sanitizer.new(
        -> env { env },
        only: ['HTTP_CUSTOM_HEADER', /(agent|input)/i]
      )
      @rack_input = StringIO.new(@plain_input.force_encoding(Encoding::ASCII_8BIT))

      sanitize_data
      @response_env['HTTP_CUSTOM_HEADER'].should != @plain_input
      @response_env['HTTP_USER_AGENT'].should != @plain_input
      @response_env['rack.input'].read.should != @plain_input
    end
  end

  describe "with custom strategy" do
    def request_env
      @plain_input = "foo bar лол".force_encoding('UTF-8')
      {
          "REQUEST_METHOD" => "POST",
          "CONTENT_TYPE" => "application/json",
          "HTTP_USER_AGENT" => @plain_input,
          "rack.input" => @rack_input,
      }
    end

    def sanitize_data(request_env = request_env())
      @uri_input = "http://bar/foo+%2F%3A+bar+%D0%BB%D0%BE%D0%BB".force_encoding('UTF-8')
      @response_env = @app.(request_env)
      sanitized_input = @response_env['rack.input'].read

      yield sanitized_input if block_given?
    end

    it "calls a default strategy (replace)" do
      @app = Rack::UTF8Sanitizer.new(-> env { env })

      input = "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      env = request_env
      sanitize_data(env) do |sanitized_input|
        sanitized_input.encoding.should == Encoding::UTF_8
        sanitized_input.should.be.valid_encoding
        sanitized_input.should != input
      end
    end

    it "calls the exception strategy" do
      @app = Rack::UTF8Sanitizer.new(-> env { env }, strategy: :exception)

      input = "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      env = request_env
      should.raise(EncodingError) { sanitize_data(env) }
    end

    it "accepts a proc as a strategy" do
      truncate = -> input { 'replace'.force_encoding(Encoding::UTF_8) }

      @app = Rack::UTF8Sanitizer.new(-> env { env }, strategy: truncate)

      input = "foo=bla&quux=bar\xED"
      @rack_input = StringIO.new input

      env = request_env
      sanitize_data(env) do |sanitized_input|
        sanitized_input.encoding.should == Encoding::UTF_8
        sanitized_input.should.be.valid_encoding
        sanitized_input.should == 'replace' 
      end
    end
  end
end
