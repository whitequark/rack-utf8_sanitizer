# Rack::UTF8Sanitizer

Rack::UTF8Sanitizer is a Rack middleware which cleans up invalid UTF8 characters in request URI and headers.

## Installation

Add this line to your application's Gemfile:

    gem 'rack-utf8_sanitizer'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install rack-utf8_sanitizer

For Rails, add this to your `application.rb`:

    config.middleware.insert_before "Rack::Lock", Rack::UTF8Sanitizer

For Rack apps, add this to `config.ru`:

    use Rack::UTF8Sanitizer

## Usage

Rack::UTF8Sanitizer divides all keys in the [Rack environment](rack.rubyforge.org/doc/SPEC.html) in two distinct groups: keys which contain raw data and the ones with percent-encoded data. The fields which are treated as percent-encoded are: `SCRIPT_NAME`, `REQUEST_PATH`, `REQUEST_URI`, `PATH_INFO`, `QUERY_STRING`, `HTTP_REFERER`.

The generic sanitization algorithm is as follows:

  1. Force the encoding to UTF-8.
  2. If the result contains invalid characters:
      1. Force the encoding to ASCII8-BIT.
      2. Re-encode it as UTF-8, replacing invalid and undefined characters as U+FFFD.

For fields with "raw data", the algorithm is applied once and the (UTF-8 encoded) result is left in the environment.

For fields with "percent-encoded data", the algorithm is applied twice to catch both invalid characters appearing as-is and invalid characters appearing in the percent encoding. The percent encoded, ASCII-8BIT encoded result is left in the environment.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
