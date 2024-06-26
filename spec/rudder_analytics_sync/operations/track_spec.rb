# frozen_string_literal: true

require 'spec_helper'

describe RudderAnalyticsSync::Operations::Track do
  context 'timestamps' do
    let(:client) { RudderAnalyticsSync::Client.new(write_key: 'key') }

    it 'uses an empty hash if no properties were provided' do
      payload = described_class.new(
        client,
        event: 'event',
        user_id: 'id'
      ).build_payload

      expect(payload[:properties]).to eq(nil)
    end

    it 'works with Time objects' do
      payload = described_class.new(
        client,
        event: 'event',
        user_id: 'id',
        timestamp: Time.new(2016, 6, 27, 23, 4, 20, '+03:00')
      ).build_payload

      expect(payload[:timestamp]).to eq('2016-06-27T23:04:20.000+03:00')
    end

    it 'works with iso8601 strings' do
      payload = described_class.new(
        client,
        event: 'event',
        user_id: 'id',
        timestamp: '2016-06-27T20:04:20Z'
      ).build_payload

      expect(payload[:timestamp]).to eq('2016-06-27T20:04:20Z')
    end

    it 'works with stubed calls' do
      stubed_client = RudderAnalyticsSync::Client.new(write_key: 'key', stub: true)
      expect(stubed_client.track(
        event: 'event',
        user_id: 'id',
        timestamp: Time.new(2016, 6, 27, 23, 4, 20, '+03:00')
      )[:status]).to eq(200)
    end
  end
end
