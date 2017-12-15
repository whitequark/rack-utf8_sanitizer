module UTF8Sanitizer
  class InvalidEncoding < UTF8Sanitizer::Error; end

  class Exception
    def call(input)
      input.
        force_encoding(Encoding::ASCII_8BIT).
        encode!(Encoding::UTF_8)
    rescue EncodingError => e
      raise InvalidEncoding, e.message
    end
  end
end

