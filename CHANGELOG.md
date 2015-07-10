Changelog
=========

Master
-------------------------

API modifications:

Features implemented:

Bugs fixed:

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
