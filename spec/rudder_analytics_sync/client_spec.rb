# frozen_string_literal: true

require 'spec_helper'

describe RudderAnalyticsSync::Client do # rubocop:disable Metrics/BlockLength
  subject(:client) do
    described_class.new(write_key: 'WRITE_KEY')
  end
  let(:now) { Time.new(2999, 12, 29).utc }

  describe '#identify' do # rubocop:disable Metrics/BlockLength
    it 'sends identity and properties to RudderStack' do # rubocop:disable Metrics/BlockLength
      time = Time.utc(2018, 3, 11, 10, 20)
      dt = DateTime.new(2018, 3, 11, 12, 20)
      date = Date.new(2018, 3, 12)

      options = {
        user_id: 'id',
        traits: {
          name: 'Philip J. Fry',
          occupation: 'Delivery Boy',
          foo_time: time,
          foo_date_time: dt,
          foo_date: date
        },
        context: {
          employer: 'Planet Express'
        },
        integrations: {
          all: true
        },
        timestamp: Time.new(2016, 3, 23).iso8601,
        message_id: 'message-id'
      }
      expected_request_body = {
        'batch' => [{
          'context' => {
            'employer' => 'Planet Express',
            'library' => {
              'name' => 'rudder-sdk-ruby-sync',
              'version' => RudderAnalyticsSync::VERSION
            },
            'traits' => {
              'name' => 'Philip J. Fry',
              'occupation' => 'Delivery Boy',
              'foo_time' => '2018-03-11T10:20:00.000Z',
              'foo_date_time' => dt.to_time.iso8601(3),
              'foo_date' => '2018-03-12'
            }
          },
          'integrations' => {
            'all' => true
          },
          'timestamp' => Time.new(2016, 3, 23).iso8601,
          'sentAt' => maybe_datetime_in_iso8601(now),
          'channel' => 'server',
          'userId' => 'id',
          'type' => 'identify',
          'traits' => {
            'name' => 'Philip J. Fry',
            'occupation' => 'Delivery Boy',
            'foo_time' => '2018-03-11T10:20:00.000Z',
            'foo_date_time' => dt.to_time.iso8601(3),
            'foo_date' => '2018-03-12'
          },
          'messageId' => 'message-id'
        }]
      }
      request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
                     .with(body: expected_request_body, basic_auth: ['WRITE_KEY', ''])

      Timecop.freeze(now) do
        client.identify(options)
        expect(request_stub).to have_been_requested.once
      end
    end

    context 'input checks' do
      before(:example) do
        stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
          .with(basic_auth: ['WRITE_KEY', ''])
      end

      it 'errors with user_id and anonymous_id blank' do
        expect { client.identify }.to raise_error(ArgumentError)
      end

      it 'allows blank user_id if anonymous_id is present' do
        expect do
          client.identify(anonymous_id: 'id')
        end.not_to raise_error
      end

      it 'allows timestamp to be a string' do
        expect do
          client.identify(
            anonymous_id: 'id',
            timestamp: Time.new(2016, 3, 23).iso8601.to_s
          )
        end.not_to raise_error
      end
    end
  end

  describe '#track' do # rubocop:disable Metrics/BlockLength
    it 'sends event and properties to RudderStack' do # rubocop:disable Metrics/BlockLength
      time = Time.utc(2018, 3, 11, 10, 20)
      dt = DateTime.new(2018, 3, 11, 12, 20)
      date = Date.new(2018, 3, 12)

      options = {
        event: 'Delivered Package',
        user_id: 'id',
        properties: {
          contents: 'Lug nuts',
          delivery_to: 'Robots of Chapek 9',
          foo_time: time,
          foo_date_time: dt,
          foo_date: date
        },
        context: {
          crew: %w[Bender Fry Leela]
        },
        integrations: {
          all: true
        },
        timestamp: Time.new(2016, 3, 23).iso8601,
        message_id: 'message-id'
      }
      expected_request_body = {
        'batch' => [{
          'context' => {
            'crew' => %w[Bender Fry Leela],
            'library' => {
              'name' => 'rudder-sdk-ruby-sync',
              'version' => RudderAnalyticsSync::VERSION
            }
          },
          'integrations' => {
            'all' => true
          },
          'timestamp' => Time.new(2016, 3, 23).iso8601,
          'sentAt' => maybe_datetime_in_iso8601(now),
          'channel' => 'server',
          'properties' => {
            'contents' => 'Lug nuts',
            'delivery_to' => 'Robots of Chapek 9',
            'foo_time' => '2018-03-11T10:20:00.000Z',
            'foo_date_time' => dt.to_time.iso8601(3),
            'foo_date' => '2018-03-12'
          },
          'event' => 'Delivered Package',
          'userId' => 'id',
          'type' => 'track',
          'messageId' => 'message-id'
        }]
      }
      request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
                     .with(body: expected_request_body, basic_auth: ['WRITE_KEY', ''])

      Timecop.freeze(now) do
        client.track(options)
        expect(request_stub).to have_been_requested.once
      end
    end

    context 'input checks' do
      before(:example) do
        stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch').with(basic_auth: ['WRITE_KEY', ''])
      end

      it 'errors without an event name' do
        expect { client.track(user_id: 'id') }.to raise_error(ArgumentError)
      end

      it 'errors with user_id and anonymous_id blank' do
        expect { client.track(event: 'test') }.to raise_error(ArgumentError)
      end

      it 'allows blank user_id if anonymous_id is present' do
        expect do
          client.track(event: 'test', anonymous_id: 'id')
        end.not_to raise_error
      end
    end
  end

  describe '#page' do # rubocop:disable Metrics/BlockLength
    it 'sends page info to RudderStack' do # rubocop:disable Metrics/BlockLength
      time = Time.utc(2018, 3, 11, 10, 20)
      dt = DateTime.new(2018, 3, 11, 12, 20)
      date = Date.new(2018, 3, 12)

      options = {
        user_id: 'id',
        name: 'Zoidberg',
        properties: {
          url: 'https://en.wikipedia.org/wiki/Zoidberg',
          foo_time: time,
          foo_date_time: dt,
          foo_date: date
        },
        context: {
          company: 'Planet Express'
        },
        integrations: {
          all: true
        },
        timestamp: Time.new(2016, 3, 23).iso8601,
        message_id: 'message-id'
      }
      expected_request_body = {
        'batch' => [{
          'context' => {
            'company' => 'Planet Express',
            'library' => {
              'name' => 'rudder-sdk-ruby-sync',
              'version' => RudderAnalyticsSync::VERSION
            }
          },
          'integrations' => {
            'all' => true
          },
          'timestamp' => Time.new(2016, 3, 23).iso8601,
          'sentAt' => maybe_datetime_in_iso8601(now),
          'channel' => 'server',
          'properties' => {
            'url' => 'https://en.wikipedia.org/wiki/Zoidberg',
            'foo_time' => '2018-03-11T10:20:00.000Z',
            'foo_date_time' => dt.to_time.iso8601(3),
            'foo_date' => '2018-03-12',
            'name' => 'Zoidberg'
          },
          'userId' => 'id',
          'name' => 'Zoidberg',
          'event' => 'Zoidberg',
          'type' => 'page',
          'messageId' => 'message-id'
        }]
      }
      request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
                     .with(body: expected_request_body, basic_auth: ['WRITE_KEY', ''])

      Timecop.freeze(now) do
        client.page(options)
        expect(request_stub).to have_been_requested.once
      end
    end

    context 'input checks' do
      before(:example) do
        stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch').with(basic_auth: ['WRITE_KEY', ''])
      end

      it 'errors with user_id and anonymous_id blank' do
        expect { client.page }.to raise_error(ArgumentError)
      end

      it 'allows blank user_id if anonymous_id is present' do
        expect do
          client.page(anonymous_id: 'id')
        end.not_to raise_error
      end
    end
  end

  describe '#group' do # rubocop:disable Metrics/BlockLength
    it 'sends group info to RudderStack' do # rubocop:disable Metrics/BlockLength
      time = Time.utc(2018, 3, 11, 10, 20)
      dt = DateTime.new(2018, 3, 11, 12, 20)
      date = Date.new(2018, 3, 12)

      options = {
        user_id: 'id',
        group_id: 'group_id',
        traits: {
          name: 'Planet Express',
          foo_time: time,
          foo_date_time: dt,
          foo_date: date
        },
        context: {
          locale: 'AL1'
        },
        integrations: {
          all: true
        },
        timestamp: Time.new(2016, 3, 23).iso8601,
        message_id: 'message-id'
      }
      expected_request_body = {
        'batch' => [{
          'context' => {
            'locale' => 'AL1',
            'library' => {
              'name' => 'rudder-sdk-ruby-sync',
              'version' => RudderAnalyticsSync::VERSION
            }
          },
          'integrations' => {
            'all' => true
          },
          'timestamp' => Time.new(2016, 3, 23).iso8601,
          'sentAt' => maybe_datetime_in_iso8601(now),
          'channel' => 'server',
          'userId' => 'id',
          'traits' => {
            'name' => 'Planet Express',
            'foo_time' => '2018-03-11T10:20:00.000Z',
            'foo_date_time' => dt.to_time.iso8601(3),
            'foo_date' => '2018-03-12'
          },
          'groupId' => 'group_id',
          'type' => 'group',
          'messageId' => 'message-id'
        }]
      }
      request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
                     .with(body: expected_request_body, basic_auth: ['WRITE_KEY', ''])

      Timecop.freeze(now) do
        client.group(options)
        expect(request_stub).to have_been_requested.once
      end
    end

    context 'input checks' do
      before(:example) do
        stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch').with(basic_auth: ['WRITE_KEY', ''])
      end

      it 'errors without a group id' do
        expect { client.group(user_id: 'id') }.to raise_error(ArgumentError)
      end

      it 'errors with user_id and anonymous_id blank' do
        expect { client.group(group_id: 'id') }.to raise_error(ArgumentError)
      end

      it 'allows blank user_id if anonymous_id is present' do
        expect do
          client.group(group_id: 'id', anonymous_id: 'id')
        end.not_to raise_error
      end
    end
  end

  describe '#alias' do # rubocop:disable Metrics/BlockLength
    it 'sends alias info to RudderStack' do # rubocop:disable Metrics/BlockLength
      options = {
        user_id: 'id',
        previous_id: 'previous_id',
        context: {
          locale: 'AL1'
        },
        integrations: {
          all: true
        },
        timestamp: Time.new(2016, 3, 23).iso8601,
        message_id: 'message-id'
      }
      expected_request_body = {
        'batch' => [{
          'context' => {
            'locale' => 'AL1',
            'library' => {
              'name' => 'rudder-sdk-ruby-sync',
              'version' => RudderAnalyticsSync::VERSION
            }
          },
          'integrations' => {
            'all' => true
          },
          'timestamp' => Time.new(2016, 3, 23).iso8601,
          'sentAt' => maybe_datetime_in_iso8601(now),
          'channel' => 'server',
          'userId' => 'id',
          'previousId' => 'previous_id',
          'type' => 'alias',
          'messageId' => 'message-id'
        }]
      }
      request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
                     .with(body: expected_request_body, basic_auth: ['WRITE_KEY', ''])

      Timecop.freeze(now) do
        client.alias(options)
        expect(request_stub).to have_been_requested.once
      end
    end

    context 'input checks' do
      before(:example) do
        stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch').with(basic_auth: ['WRITE_KEY', ''])
      end

      it 'errors without a previous id' do
        expect { client.alias(user_id: 'id') }.to raise_error(ArgumentError)
      end

      it 'errors with user_id and anonymous_id blank' do
        expect { client.alias(previous_id: 'id') }.to raise_error(ArgumentError)
      end

      it 'allows blank user_id if anonymous_id is present' do
        expect do
          client.alias(previous_id: 'id', anonymous_id: 'id')
        end.not_to raise_error
      end
    end
  end

  describe '#flush' do
    it 'does not blow up' do
      expect { client.flush }.not_to raise_error
    end
  end

  describe '#batch' do
    it 'batches events into a single request' do
      request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
                     .with do |request|
                       JSON.parse(request.body)['batch'].length == 2
                     end
      client.batch do |analytics|
        analytics.identify(user_id: 'id')
        analytics.track(event: 'Delivered Package', user_id: 'id')
      end

      expect(request_stub).to have_been_requested.once
    end
  end
end
