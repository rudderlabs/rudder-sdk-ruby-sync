# frozen_string_literal: true

require 'spec_helper'
require 'base64'
require 'socket'
require 'webrick'

describe 'RudderAnalyticsSync protocol integration' do
  class LocalDataPlane
    attr_reader :records, :url

    def initialize(statuses)
      socket = TCPServer.new('127.0.0.1', 0)
      port = socket.addr[1]
      socket.close
      @statuses = statuses
      @records = []
      @server = WEBrick::HTTPServer.new(
        BindAddress: '127.0.0.1',
        Port: port,
        Logger: WEBrick::Log.new(File::NULL),
        AccessLog: []
      )
      @server.mount_proc('/v1/batch') { |request, response| handle(request, response) }
      @thread = Thread.new { @server.start }
      @url = "http://127.0.0.1:#{port}"
      wait_until_ready(port)
    end

    def stop
      @server.shutdown
      @thread.join
    end

    private

    def handle(request, response)
      body = request.body
      if request['content-encoding'] == 'gzip'
        body = Zlib::GzipReader.new(StringIO.new(body)).read
      end
      @records << {
        authorization: request['authorization'],
        content_encoding: request['content-encoding'],
        payload: JSON.parse(body)
      }
      planned = @statuses[@records.length - 1] || @statuses.last
      response.status = planned[:status]
      response['Retry-After'] = planned[:retry_after] if planned[:retry_after]
      response['Content-Type'] = 'application/json'
      response.body = planned[:body] || '{}'
    end

    def wait_until_ready(port)
      50.times do
        begin
          TCPSocket.new('127.0.0.1', port).close
          return
        rescue Errno::ECONNREFUSED
          sleep(0.02)
        end
      end
      raise 'Local data plane did not start'
    end
  end

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  after do
    @server&.stop
    WebMock.disable_net_connect!
  end

  def client(options = {})
    RudderAnalyticsSync::Client.new({
      write_key: 'write-key',
      data_plane_url: @server.url,
      http_options: { use_ssl: false },
      max_retries: 0
    }.merge(options))
  end

  it 'sends every event API and a real batch with gzip and authentication' do
    @server = LocalDataPlane.new([{ status: 200 }])
    analytics = client

    analytics.identify(user_id: 'user-1', traits: { plan: 'pro' })
    analytics.track(user_id: 'user-1', event: 'Signed Up')
    analytics.group(user_id: 'user-1', group_id: 'group-1')
    analytics.page(user_id: 'user-1', name: 'Home')
    analytics.screen(user_id: 'user-1', name: 'Main')
    analytics.alias(user_id: 'user-2', previous_id: 'user-1')
    analytics.batch do |batch|
      batch.identify(user_id: 'user-1')
      batch.track(user_id: 'user-1', event: 'Batch Event')
      batch.group(user_id: 'user-1', group_id: 'group-1')
      batch.page(user_id: 'user-1', name: 'Batch Page')
    end

    expect(@server.records.length).to eq(7)
    expect(@server.records.map { |record| record[:payload]['batch'].map { |event| event['type'] } }).to eq([
      ['identify'], ['track'], ['group'], ['page'], ['screen'], ['alias'], %w[identify track group page]
    ])
    expect(@server.records.map { |record| record[:content_encoding] }.uniq).to eq(['gzip'])
    expect(@server.records.map { |record| record[:authorization] }.uniq).to eq([
      "Basic #{Base64.strict_encode64('write-key:')}"
    ])
  end

  it 'reports terminal HTTP failures through the compatible callback' do
    @server = LocalDataPlane.new([{ status: 400, body: '{"error":"bad request"}' }])
    callback_args = nil
    analytics = client(on_error: proc { |*args| callback_args = args; :handled_by_application })

    result = analytics.track(user_id: 'user-1', event: 'Rejected Event')

    expect(result).to eq(:handled_by_application)
    expect(callback_args[0]).to eq('400')
    expect(callback_args[1]).to eq('{"error":"bad request"}')
    expect(callback_args[2]).to be_a(Net::HTTPClientException)
    expect(callback_args[3]).to be_a(Net::HTTPBadRequest)
  end

  it 'reports request-preparation failures through the compatible callback' do
    callback_args = nil
    analytics = RudderAnalyticsSync::Client.new(
      write_key: 'write-key',
      data_plane_url: 'http://bad host',
      on_error: proc { |*args| callback_args = args; :handled_by_application }
    )

    result = analytics.track(user_id: 'user-1', event: 'Rejected Event')

    expect(result).to eq(:handled_by_application)
    expect(callback_args[0]).to be_nil
    expect(callback_args[1]).to be_nil
    expect(callback_args[2]).to be_a(URI::InvalidURIError)
    expect(callback_args[3]).to be_nil
  end

  it 'does not retry by default' do
    @server = LocalDataPlane.new([
      { status: 429, body: '{"error":"rate limited"}' },
      { status: 200 }
    ])
    callback_args = nil
    analytics = RudderAnalyticsSync::Client.new(
      write_key: 'write-key',
      data_plane_url: @server.url,
      http_options: { use_ssl: false },
      on_error: proc { |*args| callback_args = args }
    )

    analytics.track(user_id: 'user-1', event: 'Rate Limited Event')

    expect(@server.records.length).to eq(1)
    expect(callback_args[0]).to eq('429')
  end

  it 'does not retry transient network failures by default' do
    request_stub = stub_request(:post, 'https://hosted.rudderlabs.com/v1/batch')
                   .to_raise(EOFError.new)
                   .then
                   .to_return(status: 200, body: 'OK')
    callback_args = nil
    analytics = RudderAnalyticsSync::Client.new(
      write_key: 'write-key',
      gzip: false,
      on_error: proc { |*args| callback_args = args }
    )

    analytics.track(user_id: 'user-1', event: 'Network Failure Event')

    expect(request_stub).to have_been_requested.once
    expect(callback_args[0]).to be_nil
    expect(callback_args[1]).to be_nil
    expect(callback_args[2]).to be_a(EOFError)
    expect(callback_args[3]).to be_nil
  end

  it 'propagates callback exceptions without invoking the callback again' do
    @server = LocalDataPlane.new([{ status: 400, body: '{"error":"bad request"}' }])
    callback_count = 0
    analytics = client(on_error: proc do
      callback_count += 1
      raise 'callback failure'
    end)

    expect do
      analytics.track(user_id: 'user-1', event: 'Rejected Event')
    end.to raise_error(RuntimeError, 'callback failure')
    expect(callback_count).to eq(1)
  end

  it 'retries a real rate-limited request within the configured budget' do
    @server = LocalDataPlane.new([
      { status: 429, retry_after: '0', body: '{"error":"rate limited"}' },
      { status: 200 }
    ])
    analytics = client(retry_enabled: true, max_retries: 1, retry_base_delay: 0, retry_jitter_ratio: 0)

    response = analytics.track(user_id: 'user-1', event: 'Retried Event')

    expect(response.code).to eq('200')
    expect(@server.records.length).to eq(2)
    expect(@server.records[0][:payload]).to eq(@server.records[1][:payload])
  end
end
