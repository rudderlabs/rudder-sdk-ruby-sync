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
    analytics = client(on_error: proc { |*args| callback_args = args })

    result = analytics.track(user_id: 'user-1', event: 'Rejected Event')

    expect(result).to be_nil
    expect(callback_args[0]).to eq('400')
    expect(callback_args[1]).to eq('{"error":"bad request"}')
    expect(callback_args[2]).to be_a(Net::HTTPClientException)
    expect(callback_args[3]).to be_a(Net::HTTPBadRequest)
  end

  it 'retries a real rate-limited request within the configured budget' do
    @server = LocalDataPlane.new([
      { status: 429, retry_after: '0', body: '{"error":"rate limited"}' },
      { status: 200 }
    ])
    analytics = client(max_retries: 1, retry_base_delay: 0, retry_jitter_ratio: 0)

    response = analytics.track(user_id: 'user-1', event: 'Retried Event')

    expect(response.code).to eq('200')
    expect(@server.records.length).to eq(2)
  end
end
