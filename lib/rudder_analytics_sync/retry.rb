# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'time'
require 'timeout'

module RudderAnalyticsSync
  class Retry
    DEFAULT_MAX_RETRIES = 3
    DEFAULT_BASE_DELAY = 0.1
    DEFAULT_MAX_DELAY = 30.0
    DEFAULT_JITTER_RATIO = 0.2

    RETRYABLE_ERRORS = [
      Timeout::Error,
      EOFError,
      IOError,
      SocketError,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH,
      Errno::ENETUNREACH,
      Errno::ETIMEDOUT,
      Net::OpenTimeout,
      Net::ReadTimeout,
      Net::ProtocolError,
      OpenSSL::SSL::SSLError
    ].freeze

    def initialize(config, clock: proc { Time.now }, random: proc { rand })
      @config = config
      @clock = clock
      @random = random
    end

    def enabled?
      @config.retry_enabled && @config.max_retries.positive?
    end

    def max_retries
      @config.max_retries
    end

    def retries_remaining?(completed_retries)
      completed_retries < @config.max_retries
    end

    def retryable_status?(status_code)
      status_code = status_code.to_i
      status_code == 429 || (status_code >= 500 && status_code <= 599)
    end

    def retryable_error?(error)
      RETRYABLE_ERRORS.any? { |error_class| error.is_a?(error_class) }
    end

    def delay(retry_number, response = nil)
      backoff = @config.retry_base_delay * (2**(retry_number - 1))
      retry_after = retry_after_delay(response)
      base = [[backoff, retry_after].max, @config.max_retry_delay].min
      jittered = base + (base * @config.retry_jitter_ratio * @random.call)
      [jittered, @config.max_retry_delay].min
    end

    def parse_retry_after(value)
      value = value.to_s.strip
      return value.to_i if value.match?(/\A\d+\z/)

      [Time.httpdate(value) - @clock.call, 0].max
    rescue ArgumentError
      nil
    end

    private

    def retry_after_delay(response)
      return 0 unless @config.respect_retry_after && response

      parse_retry_after(response['Retry-After']) || 0
    end
  end
end
