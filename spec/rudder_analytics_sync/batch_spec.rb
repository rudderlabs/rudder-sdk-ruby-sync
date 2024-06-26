# frozen_string_literal: true

require 'spec_helper'

describe RudderAnalyticsSync::Batch do
  let(:client) { RudderAnalyticsSync::Client.new(write_key: 'key') }

  it 'supports identify, group, track and page' do
    request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
                     .with do |request|
      batch = get_batch_from(request)
      batch.map do |operation|
        operation['type']
      end == %w[identify group track page]
    end

    batch = described_class.new(client)
    batch.identify(user_id: 'id')
    batch.group(user_id: 'id', group_id: 'group_id')
    batch.track(event: 'Delivered Package', user_id: 'id')
    batch.page(
      name: 'Test Page',
      user_id: 'id',
      properties: { url: 'https://en.wikipedia.org/wiki/Zoidberg' }
    )
    batch.commit

    expect(request_stub).to have_been_requested.once
  end

  it 'allows to set common context' do
    expected_context = {
      'foo' => 'bar',
      'library' => {
        'name' => 'rudder-sdk-ruby-sync', 'version' => '2.0.1'
      }
    }
    request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
                     .with do |request|
      batch = get_batch_from(request)
      batch.map do |operation|
        operation['context']
      end == [expected_context]
    end

    batch = described_class.new(client)
    batch.context = { 'foo' => 'bar' }
    batch.track(event: 'Delivered Package', user_id: 'id')
    batch.commit

    expect(request_stub).to have_been_requested.once
  end

  it 'allows to set common integrations' do
    expected_integrations = { 'foo' => 'bar' }
    request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
                     .with do |request|
      batch = get_batch_from(request)
      batch.map do |operation|
        operation['integrations']
      end == [expected_integrations]
    end

    batch = described_class.new(client)
    batch.integrations = expected_integrations
    batch.track(event: 'Delivered Package', user_id: 'id')
    batch.commit

    expect(request_stub).to have_been_requested.once
  end

  it 'validates event payload' do
    batch = described_class.new(client)

    expect { batch.track(event: nil) }.to raise_error(ArgumentError)
  end

  it 'errors when trying to commit an empty batch' do
    batch = described_class.new(client)

    expect { batch.commit }.to raise_error(ArgumentError)
  end

  it 'can be serialized and deserialized' do
    request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
                     .with do |request|
      batch = get_batch_from(request)
      batch.map do |operation|
        operation['type']
      end == %w[identify track]
    end

    batch = described_class.new(client)
    batch.identify(user_id: 'id')
    batch.track(event: 'Delivered Package', user_id: 'id')
    serialized_batch = batch.serialize
    described_class.deserialize(client, serialized_batch).commit

    expect(request_stub).to have_been_requested.once
  end
end
