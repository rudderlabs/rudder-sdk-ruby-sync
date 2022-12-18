# frozen_string_literal: true

require 'rudder_analytics_sync'
require 'yaml'
require 'date'

local_config = YAML.safe_load(File.read('example/local_config.yaml'))

ENV['WRITE_KEY'] = local_config['WRITE_KEY']
ENV['DATA_PLANE_URL'] = local_config['DATA_PLANE_URL']

analytics = RudderAnalyticsSync::Client.new(
  write_key: ENV['WRITE_KEY'], # required
  data_plane_url: ENV['DATA_PLANE_URL'],
  stub: false,
  on_error: proc { |error_code, error_body, exception, response|
    # defaults to an empty proc
  }
)

# analytics.page(
#   user_id: 'test_user_id',
#   name: 'Test Page',
#   properties: {
#     k1: 'v1'
#   }
# )

# analytics.screen(
#   user_id: 'test_user_id',
#   name: 'Test Screen',
#   properties: {
#     k1: 'v1'
#   }
# )

# analytics.track(
#   user_id: 'test_user_id',
#   event: 'Test Track'
# )

# analytics.identify(
#   user_id: 'test_user_id_1',
#   traits: {
#     name: 'test'
#   }
# )

# analytics.group(
#   user_id: 'test_user_id_1',
#   group_id: 'group_id'
# )

# analytics.alias(
#   user_id: 'test_user_id_1',
#   previous_id: 'test_user_id'
# )

# analytics.batch do |batch| # rubocop:disable Metrics/BlockLength
#   batch.context = { source: 'test' }
#   batch.integrations = { All: false, S3: true }
  # batch.track({ event: 'test' })
  # batch.identify({ user_id: 'test' })
  # batch.screen({ user_id: 'test', name: 'test' })
  # batch.page({ user_id: 'test', name: 'test' })
  # batch.alias({ user_id: 'test', previous_id: 'test' })
  # batch.group({ group_id: 'test' })

#   batch.page(
#     user_id: 'test_user_id',
#     name: 'Test Page',
#     properties: {
#       k1: 'v1'
#     }
#   )

#   batch.screen(
#     user_id: 'test_user_id',
#     name: 'Test Screen',
#     properties: {
#       k1: 'v1'
#     }
#   )

#   batch.track(
#     user_id: 'test_user_id',
#     event: 'Test Track'
#   )

#   batch.identify(
#     user_id: 'test_user_id_1',
#     traits: {
#       name: 'test'
#     }
#   )

#   batch.group(
#     user_id: 'test_user_id_1',
#     group_id: 'group_id'
#   )

#   batch.alias(
#     user_id: 'test_user_id_1',
#     previous_id: 'test_user_id'
#   )
# end
