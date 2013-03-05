require 'uri'

module Rack
  class UTF8Sanitizer
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

    def sanitize(env)
      env.each do |key, value|
        if URI_FIELDS.include?(key)
          # URI.encode/decode expect the input to be in ASCII-8BIT.
          # However, there could be invalid UTF-8 characters both in
          # raw and percent-encoded form.
          #
          # So, first sanitize the value, then percent-decode it while
          # treating as UTF-8, then sanitize the result and encode it back.
          #
          # The result is guaranteed to be UTF-8-safe.

          decoded_value = URI.decode(
              sanitize_string(value).
              force_encoding('ASCII-8BIT'))

          env[key] = transfer_frozen(value,
              URI.encode(sanitize_string(decoded_value)))

        elsif key =~ /^HTTP_/
          # Just sanitize the headers and leave them in UTF-8. There is
          # no reason to have UTF-8 in headers, but if it's valid, let it be.

          env[key] = transfer_frozen(value,
              sanitize_string(value))
        end
      end
    end

    protected

    def sanitize_string(input)
      if input.is_a? String
        input = input.dup.force_encoding('UTF-8')

        if input.valid_encoding?
          input
        else
          input.
            force_encoding('ASCII-8BIT').
            encode!('UTF-8',
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
