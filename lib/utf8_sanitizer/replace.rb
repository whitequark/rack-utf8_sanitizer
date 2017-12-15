module UTF8Sanitizer
  class Replace
    def call(input)
      input.
        force_encoding(Encoding::ASCII_8BIT).
        encode!(Encoding::UTF_8,
                invalid: :replace,
                undef:   :replace)
    end
  end
end
