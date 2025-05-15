Changelog
=========


v1.10.1 (2025-01-10)
-------------------------

Bugs fixed:

  * Fix `URI::RFC2396_PARSER` issue with older Rubies (Tekin Süleyman, #94)


v1.10.0 (2025-01-08)
-------------------------

Changes:

  * Require Ruby 2.3.0+.  (Jean Boussier, #80)

Bugs fixed:

  * Skip sanitizing the request body if the charset is non-utf-8 (#84)
  * Don't use a mutable constant as Rack response (Jean Boussier, #86)

Chores:

  * Add the `frozen_string_literal` header (Benjamin Quorning, #90)
  * Avoid deprecation warming by switching from `URI::DEFAULT_PARSER` to `URI::RFC2396_PARSER` (Roman Gaufman, #92)

Performance:

  * Use Content-Length to read the request body if available (Jean Boussier, #80)
  * Avoid 2nd degree polynomial regexp for sanitizing content type (Jean Boussier, #82)
  * Use `Regexp#match?` over `String#=~` when testing for null bytes (Geoff Harcourt, #85)

v1.9.1 (2023-08-31)
-------------------------

Bugs fixed:

  * Fix null byte sanitisation (Szymon Madeja, #78)

v1.9.0 (2023-07-06)
-------------------------

  * Optionally sanitize null bytes (James Coleman, #75)
  * CI: add Ruby 3.2 (Peter Goldstein, #71)

v1.8.0 (2022-10-25)
-------------------------

Bugs fixed:

  * Handle EOFError (Kir Shatrov, #57)

Features implemented:

  * Allow Rack version 3 (Alexander Popov, #66)
  * Various CI chores (Olle Jonsson)
  * Move to GitHub Actions, configure Dependabot (Peter Goldstein, #62, #64)

v1.7.0 (2020-05-05)
-------------------------

  * Resolve Ruby warnings about `URI.escape` (Alexander Popov, #53)
  * README: better reflect that this also can sanitize text bodies (Zach McCormick, #47)
  * Update documentation on exception strategy handler (Josh Frankel, #52)

v1.6.0 (2018-06-06)
-------------------------

Bugs fixed:

  * Add sanitation of cookie header (John Hager, #45)

v1.5.0 (2018-02-16)
-------------------------

Bugs fixed:

  * Sanitize `nil` in `sanitize_uri_encoded_string` (David Čepelík, #44)

Features implemented:

  * Add `:only` and `:except` options (John Hager, #43)
  * Add strategies to rack-utf8_sanitizer (John Hager, #41)

    ```rb
    # Example usage in Rails config/application.rb:
    config.middleware.insert(0, Rack::UTF8Sanitizer, strategy: :exception)
    ```

v1.4.0 (2016-03-07)
-------------------------

Performance:

  * Use more performant `%char` decoding `.hex.chr` (Martin Emde, #36)
  * Make `HTTP_` a constant to avoid creating the string every loop (Martin Emde, #35)

Features implemented:

  * Add SERVER_NAME to list of sanitization (Denis Lysenko, 9644371)

Chores:

  * Add license to gemspec (Robert Reiz, #38)


v1.3.2 (2015-12-23)
-------------------------

API modifications:

Features implemented:

Bugs fixed:

  * Strip UTF-8 Byte Order Mark from the request body (Jean Boussier, #29)
  * Add options to #initialize to allow configurable sanitizable content types (Shelby Switzer, #30)

v1.3.1 (2015-07-09)
-------------------------

Bugs fixed:
  * Make sure Content-Length is adjusted. (Samuel Cochran, #26)

v1.3.0 (2015-01-26)
-------------------------

v1.2.4 (2014-11-29)
-------------------------

v1.2.3 (2014-10-08)
-------------------------

v1.2.2 (2014-07-10)
-------------------------

Features implemented:
  * Sanitize request body for all HTTP verbs. (Nathaniel Talbott, #15)
  * Add `application/json` and `text/javascript` as sanitizable content types. (Benjamin Fleischer, #12)

Bugs fixed:
  * Ensure Rack::UTF8 Sanitizer is first middleware. (Aaron Renner, #13)

v1.2.1 (2014-05-27)
-------------------------
