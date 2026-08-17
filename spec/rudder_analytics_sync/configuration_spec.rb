# frozen_string_literal: true

require 'spec_helper'

describe RudderAnalyticsSync::Configuration do
  it 'requires a write_key' do
    expect do
      described_class.new(write_key: nil)
    end.to raise_error(ArgumentError)
  end

  it 'works with symbol keys' do
    config = described_class.new(write_key: 'test')
    expect(config.write_key).to eq 'test'
  end

  it 'works with string keys' do
    config = described_class.new('write_key' => 'key')
    expect(config.write_key).to eq 'key'
  end

  context 'defaults' do
    it 'has a default error handler' do
      config = described_class.new(write_key: 'test')
      expect(config.on_error).to be_a(Proc)
    end

    it 'has a default http_options' do
      config = described_class.new(write_key: 'test')
      expect(config.http_options).to eq(use_ssl: true)
    end

    it 'has bounded retry defaults' do
      config = described_class.new(write_key: 'test')

      expect(config.retry_enabled).to eq(true)
      expect(config.max_retries).to eq(3)
      expect(config.retry_base_delay).to eq(0.1)
      expect(config.max_retry_delay).to eq(30.0)
      expect(config.retry_jitter_ratio).to eq(0.2)
      expect(config.respect_retry_after).to eq(true)
    end
  end

  it 'works with stub' do
    config = described_class.new(write_key: 'test', stub: true)
    expect(config.stub).to eq true
  end

  it 'works with user prefered logging' do
    my_logger = object_double('Logger')
    config = described_class.new(
      write_key: 'test',
      logger: my_logger
    )
    expect(config.logger).to eq(my_logger)
  end

  it 'accepts an http_options' do
    config = described_class.new(write_key: 'test', http_options: { read_timeout: 42 })
    expect(config.http_options).to eq(use_ssl: true, read_timeout: 42)
  end

  it 'accepts a data_plane_url' do
    config = described_class.new(write_key: 'test', data_plane_url: 'hosted.rudderlabs.com')
    expect(config.data_plane_url).to eq('hosted.rudderlabs.com')
  end

  it 'normalizes custom retry options' do
    config = described_class.new(
      write_key: 'test',
      max_retries: -1,
      retry_base_delay: -2,
      max_retry_delay: 12,
      retry_jitter_ratio: 4,
      respect_retry_after: false,
      retry_enabled: false
    )

    expect(config.max_retries).to eq(0)
    expect(config.retry_base_delay).to eq(0)
    expect(config.max_retry_delay).to eq(12.0)
    expect(config.retry_jitter_ratio).to eq(1)
    expect(config.respect_retry_after).to eq(false)
    expect(config.retry_enabled).to eq(false)
  end

  it 'accepts retries as a total-attempt count' do
    config = described_class.new(write_key: 'test', retries: 4)

    expect(config.max_retries).to eq(3)
  end
end
