# encoding: ascii-8bit

require 'uri'
require 'stringio'

module Rack
  class UTF8Sanitizer
    StringIO = ::StringIO

    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(sanitize(env))
    end

    # http://rack.rubyforge.org/doc/SPEC.html
    URI_FIELDS  = %w(
        SCRIPT_NAME
        REQUEST_PATH REQUEST_URI PATH_INFO
        QUERY_STRING
        HTTP_REFERER
    )

    SANITIZABLE_CONTENT_TYPES = %w(
      text/plain
      application/x-www-form-urlencoded
    )

    # MRI-optimization
    POST = 'POST'
    PUT  = 'PUT'

    def sanitize(env)
      request_method = env['REQUEST_METHOD']
      if request_method == POST || request_method == PUT
        sanitize_rack_input(env)
      end
      env.each do |key, value|
        if URI_FIELDS.include?(key)
          env[key] = transfer_frozen(value,
              sanitize_uri_encoded_string(value))
        elsif key.start_with?("HTTP_")
          # Just sanitize the headers and leave them in UTF-8. There is
          # no reason to have UTF-8 in headers, but if it's valid, let it be.
          env[key] = transfer_frozen(value,
              sanitize_string(value))
        end
      end
    end

    protected

    def sanitize_rack_input(env)
      # https://github.com/rack/rack/blob/master/lib/rack/request.rb#L42
      # Logic borrowed from Rack::Request#media_type,#media_type_params,#content_charset
      # Ignoring charset in content type.
      content_type = env['CONTENT_TYPE'].to_s.split(/\s*[;,]\s*/, 2).first.downcase
      return unless SANITIZABLE_CONTENT_TYPES.any? {|type| content_type == type }
      env['rack.input'] &&= sanitize_io(env['rack.input'])
    end

    # Modeled after Rack::RewindableInput
    # TODO: Should this delegate any methods to the original io?
    class SanitizedRackInput
      def initialize(original_io, sanitized_io)
        @original_io = original_io
        @sanitized_io = sanitized_io
      end
      def gets
        @sanitized_io.gets
      end
      def read(*args)
        @sanitized_io.read(*args)
      end
      def each(&block)
        @sanitized_io.each(&block)
      end
      def rewind
        @sanitized_io.rewind
      end
      def close
        @sanitized_io.close
      end
    end

    def sanitize_io(io)
      input = io.read
      io.close
      sanitized_io = transfer_frozen(input,
                      sanitize_string(input))
      SanitizedRackInput.new(io, StringIO.new(sanitized_io))
    end

    # URI.encode/decode expect the input to be in ASCII-8BIT.
    # However, there could be invalid UTF-8 characters both in
    # raw and percent-encoded form.
    #
    # So, first sanitize the value, then percent-decode it while
    # treating as UTF-8, then sanitize the result and encode it back.
    #
    # The result is guaranteed to be UTF-8-safe.
    def sanitize_uri_encoded_string(input)
      decoded_value = decode_string(input)
      reencode_string(decoded_value)
    end

    def reencode_string(decoded_value)
      escape_unreserved(
        sanitize_string(decoded_value))
    end

    def decode_string(input)
      unescape_unreserved(
        sanitize_string(input).
          force_encoding(Encoding::ASCII_8BIT))
    end

    # This regexp matches all 'unreserved' characters from RFC3986 (2.3),
    # plus all multibyte UTF-8 characters.
    UNRESERVED_OR_UTF8 = /[A-Za-z0-9\-._~\x80-\xFF]/

    # RFC3986, 2.2 states that the characters from 'reserved' group must be
    # protected during normalization (which is what UTF8Sanitizer does).
    #
    # However, the regexp approach used by URI.unescape is not sophisticated
    # enough for our task.
    def unescape_unreserved(input)
      input.gsub(/%([a-f\d]{2})/i) do |encoded|
        decoded = [$1.hex].pack('C')

        if decoded =~ UNRESERVED_OR_UTF8
          decoded
        else
          encoded
        end
      end
    end

    # This regexp matches unsafe characters, i.e. everything except 'reserved'
    # and 'unreserved' characters from RFC3986 (2.3), and additionally '%',
    # as percent-encoded unreserved characters could be left over from the
    # `unescape_unreserved` invocation.
    #
    # See also URI::REGEXP::PATTERN::{UNRESERVED,RESERVED}.
    UNSAFE           = /[^\-_.!~*'()a-zA-Z\d;\/?:@&=+$,\[\]%]/

    # Performs the reverse function of `unescape_unreserved`. Unlike
    # the previous function, we can reuse the logic in URI#encode
    def escape_unreserved(input)
      URI.encode(input, UNSAFE)
    end

    def sanitize_string(input)
      if input.is_a? String
        input = input.dup.force_encoding(Encoding::UTF_8)

        if input.valid_encoding?
          input
        else
          input.
            force_encoding(Encoding::ASCII_8BIT).
            encode!(Encoding::UTF_8,
                    invalid: :replace,
                    undef:   :replace)
        end
      else
        input
      end
    end

    def transfer_frozen(from, to)
      if from.frozen?
        to.freeze
      else
        to
      end
    end
  end
end
