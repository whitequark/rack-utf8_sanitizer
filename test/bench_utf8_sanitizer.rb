# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/benchmark'

require_relative '../lib/rack/utf8_sanitizer'

class RackUTF8SanitizerBenchmark < Minitest::Benchmark
  def self.bench_range
    bench_exp(10, 1_000_000, 10)
  end

  def hex
    rand(255).to_s(16)
  end

  def data(size, encode_ratio: 1.0)
    buffer = String.new
    size.times.reduce(buffer) { |str, _|
      encoded = rand + encode_ratio >= 1.0
      str << (encoded ? "%#{hex}" : '___')
    }
  end

  def setup
    @data = data(10_000_000, encode_ratio: 0.2)
  end

  def bench_urlencoded_input
    app = Rack::UTF8Sanitizer.new(->(env) { env })

    request_env = {
      'REQUEST_METHOD' => 'POST',
      'CONTENT_TYPE' => 'application/x-www-form-urlencoded'
    }

    assert_performance_linear 0.99 do |n|
      20.times do
        offset = rand((@data.size / 3) - n)
        data = @data.slice(offset, n)
        app.call(request_env.merge('rack.input' => StringIO.new(data)))
      end
    end
  end
end
