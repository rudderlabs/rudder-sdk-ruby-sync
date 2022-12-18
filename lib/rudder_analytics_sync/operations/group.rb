# frozen_string_literal: true

module RudderAnalyticsSync
  module Operations
    class Group < Operation
      def call
        batch = build_payload.merge(
          type: 'group'
        )
        if batch.length > MAX_BATCH_SIZE
          raise ArgumentError, 'Max batch size is 500 KB'
        end

        request.post('/v1/batch', batch: [batch])
      end

      def build_payload
        raise ArgumentError, 'group_id must be present' \
          unless options[:group_id]

        base_payload.merge(
          traits: options[:traits] && isoify_dates!(options[:traits]),
          groupId: options[:group_id]
        )
      end
    end
  end
end
