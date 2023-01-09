# frozen_string_literal: true

module RudderAnalyticsSync
  module Constants
    MAX_BATCH_SIZE = 500_000 # ~500 KB
    MAX_MESSAGE_SIZE = 32_000  # ~32 KB
    BASE_URL = 'https://hosted.rudderlabs.com'

    DEFAULT_HEADERS = {
      'Content-Type' => 'application/json',
      'accept' => 'application/json'
    }.freeze

    DEFAULT_CONTEXT = {
      library: {
        name: 'rudder-sdk-ruby-sync',
        version: RudderAnalyticsSync::VERSION
      }
    }.freeze
  end
end
