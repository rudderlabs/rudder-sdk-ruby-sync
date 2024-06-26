# frozen_string_literal: true

require 'rudder_analytics_sync/constants'
require 'rudder_analytics_sync/logging'
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
    end

    def post(path, payload, headers: DEFAULT_HEADERS) # rubocop:disable Metrics/AbcSize
      response = nil
      status_code = nil
      response_body = nil

      uri = URI(data_plane_url)
      if stub
        logger.debug "stubbed request to \
        #{path}: write key = #{write_key}, \
        payload = #{JSON.generate(payload)}"

        { status: 200, error: nil }
      else
        if gzip
          headers = headers.merge(
            'Content-Encoding': 'gzip'
          )
          gzip = Zlib::GzipWriter.new(StringIO.new)
          gzip << payload.to_json
          payload = gzip.close.string
        else
          payload = JSON.generate(payload)
        end
        Net::HTTP.start(uri.host, uri.port, :ENV, http_options) do |http|
          request = Net::HTTP::Post.new(path, headers)
          request.basic_auth write_key, nil
          http.request(request, payload).tap do |res|
            status_code = res.code
            response_body = res.body
            response = res
            response.value
          end
        end
      end
    rescue StandardError => e
      error_handler.call(status_code, response_body, e, response)
    end
  end
end
