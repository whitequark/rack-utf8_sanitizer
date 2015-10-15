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
end
