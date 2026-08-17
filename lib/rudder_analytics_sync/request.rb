# frozen_string_literal: true

require 'rudder_analytics_sync/constants'
require 'rudder_analytics_sync/logging'
require 'rudder_analytics_sync/retry'
require('zlib')

module RudderAnalyticsSync
  class Request
    include RudderAnalyticsSync::Logging
    include RudderAnalyticsSync::Constants

    attr_reader :write_key, :data_plane_url, :error_handler, :stub, :logger, :http_options, :gzip

    def initialize(client) # rubocop:disable Metrics/AbcSize
      @write_key = client.config.write_key
      @data_plane_url = client.config.data_plane_url || BASE_URL
      @error_handler = client.config.on_error
      @stub = client.config.stub
      @logger = client.config.logger
      @http_options = client.config.http_options
      @gzip = client.config.gzip.nil? ? true : client.config.gzip
      @retry = Retry.new(client.config)
    end

    def post(path, payload, headers: DEFAULT_HEADERS)
      uri = URI(data_plane_url)
      return stub_post(path, payload) if stub

      payload, headers = encode(payload, headers)
      execute_post(uri, path, payload, headers)
    end

    private

    def stub_post(path, payload)
      logger.debug "stubbed request to \
      #{path}: write key = #{write_key}, \
      payload = #{JSON.generate(payload)}"

      { status: 200, error: nil }
    end

    def encode(payload, headers)
      return [JSON.generate(payload), headers] unless gzip

      headers = headers.merge('Content-Encoding': 'gzip')
      writer = Zlib::GzipWriter.new(StringIO.new)
      writer << payload.to_json
      [writer.close.string, headers]
    end

    def execute_post(uri, path, payload, headers) # rubocop:disable Metrics/MethodLength
      completed_retries = 0
      loop do
        response = nil
        begin
          response = perform_post(uri, path, payload, headers)
          return response if success_status?(response.code)

          if retry_status?(response.code, completed_retries)
            completed_retries = retry_response(completed_retries, response)
            next
          end

          response.value
        rescue StandardError => e
          if response.nil? && retry_error?(e, completed_retries)
            completed_retries = retry_exception(completed_retries, e)
            next
          end

          return report_error(e, response)
        end
      end
    end

    def perform_post(uri, path, payload, headers)
      Net::HTTP.start(uri.host, uri.port, :ENV, http_options) do |http|
        request = Net::HTTP::Post.new(path, headers)
        request.basic_auth write_key, nil
        http.request(request, payload)
      end
    end

    def success_status?(status_code)
      status_code.to_i >= 200 && status_code.to_i < 300
    end

    def retry_status?(status_code, completed_retries)
      @retry.enabled? && @retry.retryable_status?(status_code) && @retry.retries_remaining?(completed_retries)
    end

    def retry_error?(error, completed_retries)
      @retry.enabled? && @retry.retryable_error?(error) && @retry.retries_remaining?(completed_retries)
    end

    def retry_response(completed_retries, response)
      retry_number = completed_retries + 1
      wait_before_retry(retry_number, response, "HTTP #{response.code}")
      retry_number
    end

    def retry_exception(completed_retries, error)
      retry_number = completed_retries + 1
      wait_before_retry(retry_number, nil, error.class.name)
      retry_number
    end

    def report_error(error, response)
      error_handler.call(response&.code, response&.body, error, response)
      nil
    end

    def wait_before_retry(retry_number, response, reason)
      delay = @retry.delay(retry_number, response)
      logger.debug "Retrying request after #{reason} in #{delay}s " \
                   "(retry #{retry_number} of #{@retry.max_retries})"
      sleep_retry_delay(delay)
    end

    def sleep_retry_delay(delay)
      sleep(delay) if delay.positive?
    end
  end
end
