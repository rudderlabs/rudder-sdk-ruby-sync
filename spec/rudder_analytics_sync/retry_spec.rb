# frozen_string_literal: true

require 'spec_helper'

describe RudderAnalyticsSync::Retry do
  def config(options = {})
    RudderAnalyticsSync::Configuration.new({ write_key: 'key' }.merge(options))
  end

  it 'retries rate limits and server failures only' do
    retry_policy = described_class.new(config)

    expect(retry_policy.retryable_status?(429)).to eq(true)
    expect(retry_policy.retryable_status?(500)).to eq(true)
    expect(retry_policy.retryable_status?(599)).to eq(true)
    expect(retry_policy.retryable_status?(400)).to eq(false)
    expect(retry_policy.retryable_status?(600)).to eq(false)
  end

  it 'retries transient network failures' do
    retry_policy = described_class.new(config)

    expect(retry_policy.retryable_error?(EOFError.new)).to eq(true)
    expect(retry_policy.retryable_error?(Net::ReadTimeout.new)).to eq(true)
    expect(retry_policy.retryable_error?(ArgumentError.new)).to eq(false)
  end

  it 'uses deterministic exponential backoff and caps the delay' do
    retry_policy = described_class.new(
      config(retry_base_delay: 1, max_retry_delay: 3, retry_jitter_ratio: 0.5),
      random: proc { 1 }
    )

    expect(retry_policy.delay(1)).to eq(1.5)
    expect(retry_policy.delay(2)).to eq(3.0)
    expect(retry_policy.delay(3)).to eq(3.0)
  end

  it 'parses numeric and HTTP-date Retry-After values' do
    now = Time.utc(2026, 8, 17, 12, 0, 0)
    retry_policy = described_class.new(config, clock: proc { now })

    expect(retry_policy.parse_retry_after('5')).to eq(5)
    expect(retry_policy.parse_retry_after((now + 7).httpdate)).to eq(7)
    expect(retry_policy.parse_retry_after((now - 7).httpdate)).to eq(0)
    expect(retry_policy.parse_retry_after('invalid')).to be_nil
  end

  it 'uses Retry-After as a bounded floor' do
    response = { 'Retry-After' => '20' }
    retry_policy = described_class.new(
      config(retry_base_delay: 1, max_retry_delay: 10, retry_jitter_ratio: 0),
      random: proc { 0 }
    )

    expect(retry_policy.delay(1, response)).to eq(10.0)
  end

  it 'can ignore Retry-After' do
    response = { 'Retry-After' => '20' }
    retry_policy = described_class.new(
      config(retry_base_delay: 1, max_retry_delay: 30, retry_jitter_ratio: 0, respect_retry_after: false)
    )

    expect(retry_policy.delay(1, response)).to eq(1.0)
  end
end
