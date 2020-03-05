# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = "rack-utf8_sanitizer"
  gem.version       = '1.7.0'
  gem.authors       = ["whitequark"]
  gem.license       = "MIT"
  gem.email         = ["whitequark@whitequark.org"]
  gem.description   = %{Rack::UTF8Sanitizer is a Rack middleware which cleans up } <<
                      %{invalid UTF8 characters in request URI and headers.}
  gem.summary       = gem.description
  gem.homepage      = "http://github.com/whitequark/rack-utf8_sanitizer"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.required_ruby_version = '>= 1.9.3'

  gem.add_dependency             "rack", '>= 1.0', '< 3.0'

  gem.add_development_dependency "bacon"
  gem.add_development_dependency "bacon-colored_output"
  gem.add_development_dependency "rake"
end
