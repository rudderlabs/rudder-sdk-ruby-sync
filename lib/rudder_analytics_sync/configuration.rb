# frozen_string_literal: true

require 'rudder_analytics_sync/logging'
require 'rudder_analytics_sync/retry'

module RudderAnalyticsSync
  class Configuration
    include RudderAnalyticsSync::Utils
    include RudderAnalyticsSync::Logging
    attr_reader :write_key, :data_plane_url, :on_error, :stub, :logger, :http_options, :gzip,
                :retry_enabled, :max_retries, :retry_base_delay, :max_retry_delay,
                :retry_jitter_ratio, :respect_retry_after

    def initialize(settings = {})
      symbolized_settings = symbolize_keys(settings)
      @write_key = symbolized_settings[:write_key]
      @data_plane_url = symbolized_settings[:data_plane_url]
      @on_error = symbolized_settings[:on_error] || proc {}
      @stub = symbolized_settings[:stub]
      @logger = default_logger(symbolized_settings[:logger])
      @http_options = { use_ssl: true }
                      .merge(symbolized_settings[:http_options] || {})
      @gzip = symbolized_settings[:gzip]
      configure_retry(symbolized_settings)
      raise ArgumentError, 'Missing required option :write_key' \
        unless @write_key
    end

    private

    def configure_retry(settings)
      @retry_enabled = settings.key?(:retry_enabled) ? settings[:retry_enabled] : true
      @max_retries = normalize_max_retries(settings)
      @retry_base_delay = non_negative_number(settings.fetch(:retry_base_delay, Retry::DEFAULT_BASE_DELAY))
      @max_retry_delay = non_negative_number(settings.fetch(:max_retry_delay, Retry::DEFAULT_MAX_DELAY))
      @retry_jitter_ratio = [[settings.fetch(:retry_jitter_ratio, Retry::DEFAULT_JITTER_RATIO).to_f, 0].max, 1].min
      @respect_retry_after = settings.key?(:respect_retry_after) ? settings[:respect_retry_after] : true
    end

    def normalize_max_retries(settings)
      value = if settings.key?(:max_retries)
                settings[:max_retries]
              elsif settings.key?(:retries)
                settings[:retries].to_i - 1
              else
                Retry::DEFAULT_MAX_RETRIES
              end
      [value.to_i, 0].max
    end

    def non_negative_number(value)
      [value.to_f, 0].max
    end
  end
end
