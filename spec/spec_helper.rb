# frozen_string_literal: true

# Start before the SDK is loaded so that SimpleCov measures all of lib/.
require 'simplecov'
require 'simplecov_json_formatter'

SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new(
  [SimpleCov::Formatter::HTMLFormatter, SimpleCov::Formatter::JSONFormatter]
)

SimpleCov.start do
  # Count every SDK file, including files loaded before SimpleCov starts (version.rb via the gemspec) or never loaded.
  track_files 'lib/**/*.rb'
  add_filter '/spec/'
  enable_coverage :branch
end

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'rudder_analytics_sync'
require 'webmock/rspec'
require 'timecop'
require 'pry'

WebMock.disable_net_connect!

def maybe_datetime_in_iso8601(datetime)
  case datetime
  when Time
    time_in_iso8601 datetime
  when DateTime
    time_in_iso8601 datetime.to_time
  when Date
    date_in_iso8601 datetime
  else
    datetime
  end
end

def time_in_iso8601(time, fraction_digits = 3)
  fraction = (format('.%06i', time.usec)[0, fraction_digits + 1] if fraction_digits.positive?)

  "#{time.strftime('%Y-%m-%dT%H:%M:%S')}#{fraction}#{formatted_offset(time, true, 'Z')}"
end

def date_in_iso8601(date)
  date.strftime('%F')
end

def formatted_offset(time, colon = true, alternate_utc_string = nil)
  (time.utc? && alternate_utc_string) || seconds_to_utc_offset(time.utc_offset, colon)
end

def seconds_to_utc_offset(seconds, colon = true)
  format((colon ? UTC_OFFSET_WITH_COLON : UTC_OFFSET_WITHOUT_COLON), (seconds.negative? ? '-' : '+'), (seconds.abs / 3600), ((seconds.abs % 3600) / 60))
end

def get_batch_from(request)
  batch = {}
  if request.headers['Content-Encoding'] == 'gzip'
    gz = Zlib::GzipReader.new(StringIO.new(request.body.to_s))
    uncompressed_string = gz.read
    batch = JSON.parse(uncompressed_string)['batch']
  else
    batch = JSON.parse(request.body)['batch']
  end
  batch
end
