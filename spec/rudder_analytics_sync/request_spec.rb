# frozen_string_literal: true

require 'spec_helper'

describe RudderAnalyticsSync::Request do
  context 'API errors handling' do
    before(:example) do
      stub_request(:post, 'https://hosted.rudderlabs.com/v1/track')
        .with(basic_auth: ['key', ''])
        .to_return(status: 500, body: { error: 'Does not compute' }.to_json)
    end

    it 'does not raise an error with default client' do
      client = RudderAnalyticsSync::Client.new(write_key: 'key', max_retries: 0)
      expect do
        described_class.new(client).post('/v1/track', {})
      end.not_to raise_error
    end

    it 'passes http errors to the on_error hook' do
      error_code = nil
      error_body = nil
      response = nil
      exception = nil
      error_handler = proc do |code, body, res, e|
        error_code = code
        error_body = body
        response = res
        exception = e
      end
      client = RudderAnalyticsSync::Client.new(
        write_key: 'key',
        max_retries: 0,
        on_error: error_handler
      )
      described_class.new(client).post('/v1/track', {})

      expect(error_code).to eq('500')
      expect(error_body).to eq({ error: 'Does not compute' }.to_json)
      expect(response).to be_a(Net::HTTPFatalError)
      expect(exception).to be_a(Net::HTTPInternalServerError)
    end
  end

  context 'retry handling' do
    it 'retries 429 responses until success' do
      request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/track')
                     .with(basic_auth: ['key', ''])
                     .to_return(
                       { status: 429, body: { error: 'Rate limited' }.to_json },
                       { status: 200, body: 'OK' }
                     )
      client = RudderAnalyticsSync::Client.new(
        write_key: 'key', retry_enabled: true, retry_base_delay: 0, retry_jitter_ratio: 0
      )
      request = described_class.new(client)
      allow(request).to receive(:sleep_retry_delay)

      response = request.post('/v1/track', {})

      expect(response.code).to eq('200')
      expect(request_stub).to have_been_requested.twice
    end

    it 'honors Retry-After without a real sleep' do
      stub_request(:post, 'https://hosted.rudderlabs.com/v1/track')
        .with(basic_auth: ['key', ''])
        .to_return(
          { status: 429, headers: { 'Retry-After' => '2' }, body: 'Rate limited' },
          { status: 200, body: 'OK' }
        )
      client = RudderAnalyticsSync::Client.new(
        write_key: 'key', retry_enabled: true, retry_base_delay: 0.1, retry_jitter_ratio: 0
      )
      request = described_class.new(client)
      allow(request).to receive(:sleep_retry_delay)

      request.post('/v1/track', {})

      expect(request).to have_received(:sleep_retry_delay).with(2.0)
    end

    it 'retries transient network errors' do
      request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/track')
                     .with(basic_auth: ['key', ''])
                     .to_raise(EOFError.new)
                     .then
                     .to_return(status: 200, body: 'OK')
      client = RudderAnalyticsSync::Client.new(
        write_key: 'key', retry_enabled: true, retry_base_delay: 0, retry_jitter_ratio: 0
      )
      request = described_class.new(client)

      response = request.post('/v1/track', {})

      expect(response.code).to eq('200')
      expect(request_stub).to have_been_requested.twice
    end

    it 'does not retry terminal client errors' do
      request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/track')
                     .with(basic_auth: ['key', ''])
                     .to_return(status: 400, body: 'Bad request')
      error_code = nil
      client = RudderAnalyticsSync::Client.new(
        write_key: 'key',
        on_error: proc { |code, _body, _exception, _response| error_code = code }
      )
      request = described_class.new(client)
      allow(request).to receive(:sleep_retry_delay)

      request.post('/v1/track', {})

      expect(error_code).to eq('400')
      expect(request_stub).to have_been_requested.once
      expect(request).not_to have_received(:sleep_retry_delay)
    end

    it 'reports the final response after exhausting the retry budget' do
      request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/track')
                     .with(basic_auth: ['key', ''])
                     .to_return(status: 503, body: 'Unavailable')
      callback_args = nil
      client = RudderAnalyticsSync::Client.new(
        write_key: 'key', retry_enabled: true, max_retries: 2, retry_base_delay: 0, retry_jitter_ratio: 0,
        on_error: proc { |*args| callback_args = args }
      )

      described_class.new(client).post('/v1/track', {})

      expect(request_stub).to have_been_requested.times(3)
      expect(callback_args[0]).to eq('503')
      expect(callback_args[1]).to eq('Unavailable')
      expect(callback_args[2]).to be_a(Net::HTTPFatalError)
      expect(callback_args[3]).to be_a(Net::HTTPServiceUnavailable)
    end
  end
end
