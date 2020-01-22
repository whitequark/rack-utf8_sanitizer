# Rack::UTF8Sanitizer

Rack::UTF8Sanitizer is a Rack middleware which cleans up invalid UTF8 characters in request URI and headers. Additionally,
it cleans up invalid UTF8 characters in the request body (depending on the configurable content type filters) by reading
the input into a string, sanitizing the string, then replacing the Rack input stream with a rewindable input stream backed
by the sanitized string.

## Installation

Add this line to your application's Gemfile:

    gem 'rack-utf8_sanitizer'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-utf8_sanitizer

For Rails, add this to your `application.rb`:

``` ruby
config.middleware.insert 0, Rack::UTF8Sanitizer
```

For Rack apps, add this to `config.ru`:

``` ruby
use Rack::UTF8Sanitizer
```

## Usage

Rack::UTF8Sanitizer divides all keys in the [Rack environment](http://rack.rubyforge.org/doc/SPEC.html) in two distinct groups: keys which contain raw data and the ones with percent-encoded data. The fields which are treated as percent-encoded are: `SCRIPT_NAME`, `REQUEST_PATH`, `REQUEST_URI`, `PATH_INFO`, `QUERY_STRING`, `HTTP_REFERER`.

The generic sanitization algorithm is as follows:

  1. Force the encoding to UTF-8.
  2. If the result contains invalid characters:
      1. Force the encoding to ASCII8-BIT.
      2. Re-encode it as UTF-8, replacing invalid and undefined characters as U+FFFD.

For fields with "raw data", the algorithm is applied once and the (UTF-8 encoded) result is left in the environment.

For fields with "percent-encoded data", the algorithm is applied twice to catch both invalid characters appearing as-is and invalid characters appearing in the percent encoding. The percent encoded, ASCII-8BIT encoded result is left in the environment.

### Sanitizable content types

The default content types to be sanitized are 'text/plain', 'application/x-www-form-urlencoded', 'application/json', 'text/javascript'. You may wish to modify this, for example if your app accepts specific or custom media types in the CONTENT_TYPE header. If you want to change the sanitizable content types, you can pass options when using Rack::UTF8Sanitizer.

To add sanitizable content types to the list of defaults, pass the `additional_content_types` options when using Rack::UTF8Sanitizer, e.g.

    config.middleware.insert 0, Rack::UTF8Sanitizer, additional_content_types: ['application/vnd.api+json']

To explicitly set sanitizable content types and override the defaults, use the `sanitizable_content_types` option:

    config.middleware.insert 0, Rack::UTF8Sanitizer, sanitizable_content_types: ['application/vnd.api+json']

### Whitelist/Blacklist Rack Env Keys

Using the `:only` and `:except` keys you can skip sanitation of values in the Rack Env. `:only` and `:except` are arrays that can contain strings or regular expressions.

Only sanitize the body, query string, and url of a request.

```ruby
config.middleware.insert 0, Rack::UTF8Sanitizer, only: ['rack.input', 'PATH_INFO', 'QUERY_STRING']
```

Sanitize everything except HTTP headers.

```ruby
config.middleware.insert 0, Rack::UTF8Sanitizer, except: [/HTTP_.+/]
```

### Strategies

There are two built in strategies for handling invalid characters. The default strategy is `:replace`, which will cause any invalid characters to be replaces with the unicode replacement character (�). The second built in strategy is `:exception` which will cause an `EncodingError` exception to be raised if invalid characters are found (the exception can then be handled by another Rack middleware).

This is an example of handling the `:exception` strategy with additional middleware:

```ruby
require "./your/middleware/directory/utf8_sanitizer_exception_handler.rb"

config.middleware.insert 0, Rack::UTF8SanitizerExceptionHandler
config.middleware.insert_after Rack::UTF8SanitizerExceptionHandler, Rack::UTF8Sanitizer, strategy: :exception
```

Note: The exception handling middleware must be inserted before `Rack::UTF8Sanitizer`

```ruby
module Rack
  class UTF8SanitizerExceptionHandler
    def initialize(app)
      @app = app
    end

    def call(env)
      @app.call(env)
    rescue EncodingError => exception
      # OPTIONAL: Add error logging service of your choice here
      return [400, {}, ["Bad Request"]]
    end
  end
end
```

An object that responds to `#call` and accepts the offending string with invalid characters as an argument can also be passed as a `:strategy`. This is how you can define custom strategies.

```ruby
config.middleware.insert 0, Rack::UTF8Sanitizer, strategy: :exception
```

```ruby
replace_string = lambda do |_invalid|
  Rails.logger.warn('Replacing invalid string')

  '<Bad Encoding>'.freeze
end

config.middleware.insert 0, Rack::UTF8Sanitizer, strategy: replace_string
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

To run the tests, run `rake spec` in the project directory.
