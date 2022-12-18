# frozen_string_literal: true

module RudderAnalyticsSync
  module Operations
    class Track < Operation
      def call
        batch = build_payload.merge(
          type: 'track'
        )
        if batch.length > MAX_BATCH_SIZE
          raise ArgumentError, 'Max batch size is 500 KB'
        end

        request.post('/v1/batch', batch: [batch])
      end

      def build_payload
        raise ArgumentError, 'event name must be present' unless options[:event]

        properties = options[:properties] && isoify_dates!(options[:properties])

        if properties
          base_payload[:properties] = properties
        end
        base_payload.merge(
          event: options[:event]
        )
      end
    end
  end
end
