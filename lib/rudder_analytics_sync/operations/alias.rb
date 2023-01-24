# frozen_string_literal: true

module RudderAnalyticsSync
  module Operations
    class Alias < Operation
      def call
        batch = build_payload.merge(
          type: 'alias'
        )
        if batch.inspect.length > MAX_MESSAGE_SIZE
          raise ArgumentError, 'Max message size is 32 KB'
        end

        request.post('/v1/batch', { 'batch' => [batch] })
      end

      def build_payload
        raise ArgumentError, 'previous_id must be present' \
          unless options[:previous_id]

        base_payload.merge(
          previousId: options[:previous_id]
        )
      end
    end
  end
end
