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
      @uri_input   = "foo%E0".force_encoding('UTF-8')
    end

    behaves_like :does_sanitize_plain
    behaves_like :does_sanitize_uri
  end

  describe "with invalid, incorrectly percent-encoded UTF-8 URI input" do
    before do
      @uri_input   = "foo%E0\xe0".force_encoding('UTF-8')
    end

    behaves_like :does_sanitize_uri
  end

  describe "with invalid ASCII-8BIT input" do
    before do
      @plain_input = "foo\xe0"
      @uri_input   = "foo%E0"
    end

    behaves_like :does_sanitize_plain
    behaves_like :does_sanitize_uri
  end

  describe "with invalid, incorrectly percent-encoded ASCII-8BIT URI input" do
    before do
      @uri_input   = "foo%E0\xe0"
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
      @uri_input   = "foo+bar+%D0%BB%D0%BE%D0%BB".force_encoding('UTF-8')
    end

    behaves_like :identity_plain
    behaves_like :identity_uri
  end

  describe "with valid, not percent-encoded UTF-8 URI input" do
    before do
      @uri_input   = "foo+bar+лол".force_encoding('UTF-8')
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
      @uri_input   = "bar+baz"
    end

    behaves_like :identity_plain
    behaves_like :identity_uri
  end

  describe "with frozen strings" do
    before do
      @plain_input = "bar baz".freeze
      @uri_input   = "bar+baz".freeze
    end

    it "preserves the frozen? status of input" do
      env  = @app.({ "HTTP_USER_AGENT" => @plain_input,
                     "REQUEST_PATH" => @uri_input })

      env["HTTP_USER_AGENT"].should.be.frozen
      env["REQUEST_PATH"].should.be.frozen
    end
  end
end
