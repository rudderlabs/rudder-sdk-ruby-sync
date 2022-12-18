# frozen_string_literal: true

require 'rudder_analytics_sync/utils'
require 'rudder_analytics_sync/constants'

module RudderAnalyticsSync
  module Operations
    class Operation
      include RudderAnalyticsSync::Utils
      include RudderAnalyticsSync::Constants

      def initialize(client, options = {})
        @options = options
        @context = DEFAULT_CONTEXT.merge(options[:context].to_h)
        @request = Request.new(client)
      end

      def call
        raise 'Must be implemented in a subclass'
      end

      private

      attr_reader :options, :request, :context

      def base_payload # rubocop:disable Metrics/AbcSize
        check_identity!
        current_time = Time.now.utc

        payload = {
          context: context,
          integrations: options[:integrations] || { All: true },
          timestamp: maybe_datetime_in_iso8601(options[:timestamp] || Time.now.utc),
          sentAt: maybe_datetime_in_iso8601(current_time),
          messageId: options[:message_id] || uid,
          channel: 'server'
        }

        # add the properties if present
        if options[:properties]
          payload = payload.merge({ properties: options[:properties] })
        end

        # add the userId if present
        if options[:user_id]
          payload = payload.merge({ userId: options[:user_id] })
        end

        # add the anonymousId if present
        if options[:anonymous_id]
          payload = payload.merge({ anonymousId: options[:anonymous_id] })
        end
        payload
      end

      def check_identity!
        raise ArgumentError, 'user_id or anonymous_id must be present' \
          unless options[:user_id] || options[:anonymous_id]
      end
    end
  end
end
