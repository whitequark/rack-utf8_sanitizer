module UTF8Sanitizer
  class Replace
    attr_reader :replace

    def initialize(options)
      @replace = options.fetch(:replace_with) { "\uFFFD" }
    end

    def call(input)
      input.
        force_encoding(Encoding::ASCII_8BIT).
        encode!(Encoding::UTF_8,
                invalid: :replace,
                undef:   :replace,
                replace: replace)
    end
  end
end
