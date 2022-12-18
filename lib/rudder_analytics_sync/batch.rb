# frozen_string_literal: true

require 'rudder_analytics_sync/constants'

module RudderAnalyticsSync
  class Batch
    include RudderAnalyticsSync::Utils
    include RudderAnalyticsSync::Constants

    attr_reader :client, :payload, :batch_context, :batch_integrations

    def self.deserialize(client, payload)
      new(client, symbolize_keys(payload))
    end

    def initialize(client, payload = { batch: [] })
      @client = client
      @payload = payload
    end

    def identify(options)
      add(Operations::Identify, options, __method__)
    end

    def track(options)
      add(Operations::Track, options, __method__)
    end

    def page(options)
      add(Operations::Page, options, __method__)
    end

    def screen(options)
      add(Operations::Screen, options, __method__)
    end

    def group(options)
      add(Operations::Group, options, __method__)
    end

    def alias(options)
      add(Operations::Alias, options, __method__)
    end

    def context=(context)
      @batch_context = context
    end

    def integrations=(integrations)
      @batch_integrations = integrations
    end

    def serialize
      payload
    end

    def commit
      if payload[:batch].length.zero?
        raise ArgumentError, 'A batch must contain at least one action'
      end

      if payload[:batch].length > MAX_BATCH_SIZE
        raise ArgumentError, 'Max batch size is 500 KB'
      end

      Request.new(client).post('/v1/batch', payload)
    end

    private

    def add(operation_class, options, action) # rubocop:disable Metrics/AbcSize
      operation = operation_class.new(client, symbolize_keys(options))
      operation_payload = operation.build_payload
      operation_payload[:context] = operation_payload[:context].merge(batch_context || {})
      operation_payload[:integrations] = batch_integrations || operation_payload[:integrations]
      operation_payload[:type] = action
      if operation_payload.length > MAX_MESSAGE_SIZE
        raise ArgumentError, 'Max event size is 32 KB'
      end

      payload[:batch] << operation_payload
    end
  end
end
