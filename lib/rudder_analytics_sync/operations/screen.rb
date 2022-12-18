# frozen_string_literal: true

module RudderAnalyticsSync
  module Operations
    class Screen < Operation
      def call
        batch = build_payload.merge(
          type: 'screen'
        )
        if batch.inspect.length > MAX_MESSAGE_SIZE
          raise ArgumentError, 'Max message size is 32 KB'
        end

        request.post('/v1/batch', batch: [batch])
      end

      def build_payload
        properties = (options[:properties] && isoify_dates!(options[:properties])) || {}

        base_payload.merge(
          name: options[:name],
          event: options[:name],
          properties: properties.merge({ name: options[:name] })
        )
      end
    end
  end
end
