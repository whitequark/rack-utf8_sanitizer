# encoding: ascii-8bit

require 'uri'
require 'stringio'
require 'rack/request'

module Rack
  class UTF8Sanitizer
    StringIO = ::StringIO
    BAD_REQUEST = [400, { "Content-Type" => "text/plain" }, ["Bad Request"]]
    NULL_BYTE_REGEX = /\x00/.freeze

    class NullByteInString < StandardError; end

    # options[:sanitizable_content_types] Array
    # options[:additional_content_types] Array
    def initialize(app, options={})
      @app = app
      @strategy = build_strategy(options)
      @sanitizable_content_types = options[:sanitizable_content_types]
      @sanitizable_content_types ||= SANITIZABLE_CONTENT_TYPES + (options[:additional_content_types] || [])
      @only = Array(options[:only]).flatten
      @except = Array(options[:except]).flatten
      @sanitize_null_bytes = options.fetch(:sanitize_null_bytes, false)
    end

    def call(env)
      begin
        env = sanitize(env)
      rescue EOFError
        return BAD_REQUEST
      end
      @app.call(env)
    end

    DEFAULT_STRATEGIES = {
      replace: lambda do |input, sanitize_null_bytes: false|
        input.
          force_encoding(Encoding::ASCII_8BIT).
          encode!(Encoding::UTF_8,
                  invalid: :replace,
                  undef:   :replace)
        if sanitize_null_bytes
          input = input.gsub(NULL_BYTE_REGEX, "")
        end
        input
      end,
      exception: lambda do |input, sanitize_null_bytes: false|
        input.
          force_encoding(Encoding::ASCII_8BIT).
          encode!(Encoding::UTF_8)
        if sanitize_null_bytes && input =~ NULL_BYTE_REGEX
          raise NullByteInString
        end
        input
      end
    }.freeze

    # https://github.com/rack/rack/blob/main/SPEC.rdoc
    URI_FIELDS  = %w(
        SCRIPT_NAME
        REQUEST_PATH REQUEST_URI PATH_INFO
        QUERY_STRING
        HTTP_REFERER
        ORIGINAL_FULLPATH
        ORIGINAL_SCRIPT_NAME
        SERVER_NAME
    ).map(&:freeze).freeze

    SANITIZABLE_CONTENT_TYPES = %w(
      text/plain
      application/x-www-form-urlencoded
      application/json
      text/javascript
    ).map(&:freeze).freeze

    URI_ENCODED_CONTENT_TYPES = %w(
      application/x-www-form-urlencoded
    ).map(&:freeze).freeze

    HTTP_ = 'HTTP_'.freeze

    def sanitize(env)
      sanitize_rack_input(env)
      sanitize_cookies(env)
      env.each do |key, value|
        next if skip?(key)

        if URI_FIELDS.include?(key)
          env[key] = transfer_frozen(value,
              sanitize_uri_encoded_string(value))
        elsif key.to_s.start_with?(HTTP_)
          # Just sanitize the headers and leave them in UTF-8. There is
          # no reason to have UTF-8 in headers, but if it's valid, let it be.
          env[key] = transfer_frozen(value,
              sanitize_string(value))
        end
      end
    end

    protected

    def skip?(rack_env_key)
      return true if !@except.empty? && @except.any? { |matcher| rack_env_key[matcher] }
      return true if !@only.empty? && @only.none? { |matcher| rack_env_key[matcher] }

      false
    end

    def build_strategy(options)
      strategy = options.fetch(:strategy) { :replace }

      return strategy unless DEFAULT_STRATEGIES.key?(strategy)

      DEFAULT_STRATEGIES[strategy]
    end

    def sanitize_rack_input(env)
      request = Rack::Request.new(env)
      content_type = request.media_type
      return unless @sanitizable_content_types.any? {|type| content_type == type }

      charset = request.content_charset
      return if charset && charset.downcase != 'utf-8'

      uri_encoded = URI_ENCODED_CONTENT_TYPES.any? {|type| content_type == type}

      if env['rack.input']
        content_length = if env['CONTENT_LENGTH']
          env['CONTENT_LENGTH'].to_i
        end
        sanitized_input = sanitize_io(env['rack.input'], uri_encoded, content_length)

        env['rack.input'] = sanitized_input
        env['CONTENT_LENGTH'] &&= sanitized_input.size.to_s
      end
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

      def size
        # StringIO#size is bytesize
        @sanitized_io.size
      end

      def close
        @sanitized_io.close
        @original_io.close if @original_io.respond_to?(:close)
      end
    end

    def sanitize_io(io, uri_encoded = false, content_length = nil)
      input = if content_length && content_length >= 0
        io.read(content_length)
      else
        io.read
      end
      sanitized_input = sanitize_string(strip_byte_order_mark(input))
      if uri_encoded
        sanitized_input = sanitize_uri_encoded_string(sanitized_input).
          force_encoding(Encoding::UTF_8)
      end
      sanitized_input = transfer_frozen(input, sanitized_input)
      SanitizedRackInput.new(io, StringIO.new(sanitized_input))
    end

    # Cookies need to be split and then sanitized as url encoded strings
    # since the cookie string itself is not url encoded (separated by `;`),
    # and the normal method of `sanitize_uri_encoded_string` would break
    # later cookie parsing in the case that a cookie value contained an
    # encoded `;`.
    def sanitize_cookies(env)
      return unless env['HTTP_COOKIE']

      env['HTTP_COOKIE'] = env['HTTP_COOKIE']
        .split(/[;,] */n)
        .map { |cookie| sanitize_uri_encoded_string(cookie) }
        .join('; ')
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
      return input if input.nil?
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
    UNRESERVED_OR_UTF8 = /[A-Za-z0-9\-._~\x80-\xFF]/.freeze
    UNRESERVED_OR_UTF8_OR_NULL = /[A-Za-z0-9\-._~\x00\x80-\xFF]/.freeze

    # RFC3986, 2.2 states that the characters from 'reserved' group must be
    # protected during normalization (which is what UTF8Sanitizer does).
    #
    # However, the regexp approach used by URI.unescape is not sophisticated
    # enough for our task.
    def unescape_unreserved(input)
      input.gsub(/%([a-f\d]{2})/i) do |encoded|
        decoded = $1.hex.chr

        decodable_regex = @sanitize_null_bytes ? UNRESERVED_OR_UTF8_OR_NULL : UNRESERVED_OR_UTF8
        if decoded =~ decodable_regex
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
      URI::DEFAULT_PARSER.escape(input, UNSAFE)
    end

    def sanitize_string(input)
      if input.is_a? String
        input = input.dup.force_encoding(Encoding::UTF_8)

        if input.valid_encoding? && !(@sanitize_null_bytes && input =~ NULL_BYTE_REGEX)
          input
        else
          @strategy.call(input, sanitize_null_bytes: @sanitize_null_bytes)
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

    UTF8_BOM = "\xef\xbb\xbf".force_encoding(Encoding::BINARY).freeze
    UTF8_BOM_SIZE = UTF8_BOM.bytesize

    def strip_byte_order_mark(input)
      return input unless input.start_with?(UTF8_BOM)
      input.byteslice(UTF8_BOM_SIZE..-1)
    end
  end
end
