# frozen_string_literal: true

module RudderAnalyticsSync
  module Operations
    class Identify < Operation
      def call
        batch = build_payload.merge(
          type: 'identify'
        )
        if batch.length > MAX_BATCH_SIZE
          raise ArgumentError, 'Max batch size is 500 KB'
        end

        request.post('/v1/batch', batch: [batch])
      end

      def build_payload
        merged_payload = base_payload
        if options[:traits]
          merged_payload = merged_payload.merge(
            traits: options[:traits] && isoify_dates!(options[:traits])
          )
          merged_payload[:context][:traits] = options[:traits] && isoify_dates!(options[:traits])
        end
        merged_payload
      end
    end
  end
end
