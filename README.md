<p align="center">
  <a href="https://rudderstack.com/">
    <img src="https://user-images.githubusercontent.com/59817155/121357083-1c571300-c94f-11eb-8cc7-ce6df13855c9.png">
  </a>
</p>

<p align="center"><b>The Customer Data Platform for Developers</b></p>

<p align="center">
  <b>
    <a href="https://rudderstack.com">Website</a>
    ·
    <a href="https://www.rudderstack.com/docs/sources/event-streams/sdks/rudderstack-ruby-sdk-sync/">Documentation</a>
    ·
    <a href="https://rudderstack.com/join-rudderstack-slack-community">Community Slack</a>
  </b>
</p>

<p align="center"><a href="https://rubygems.org/gems/rudder_analytics_sync/"><img src="https://img.shields.io/gem/v/rudder_analytics_sync?style=flat"/></a></p>

----

# RudderStack Ruby SDK

The RudderStack Ruby SDK lets you send customer event data from your Ruby applications to your specified destinations.

## SDK setup requirements

- Set up a [RudderStack open source](https://app.rudderstack.com/signup?type=opensource) account.
- Set up a Ruby source in the dashboard.
- Copy the write key and the data plane URL. For more information, refer to the [Ruby SDK documentation](https://www.rudderstack.com/docs/sources/event-streams/sdks/rudderstack-ruby-sdk-sync/#sdk-setup-requirements).

## Installation

To install the RudderStack Ruby SDK, add this line to your application's Gem file:

```ruby
gem 'rudder_analytics_sync'
```

You can also install it yourself by running the following command:

```bash
gem install rudder_analytics_sync
```

## Using the SDK

To use the Ruby SDK, create a client instance as shown:

```ruby
analytics = RudderAnalyticsSync::Client.new(
  write_key: 'WRITE_KEY', # Required
  data_plane_url: 'DATA_PLANE_URL',
  stub: false,
  gzip: true,  # Set to false to disable Gzip compression
  on_error: proc { |error_code, error_body, exception, response|
    # defaults to an empty proc
  }
)
```

You can then use this client to send the events. A sample `track` call sent using the client is shown below:

```ruby
analytics.track(
  user_id: 12345,
  event: 'Test Event'
)
```

## Gzip support

From version 2.0.0, the Ruby SDK supports Gzip compression and it is enabled (set to `true`) by default. However, you can disable this feature by setting the `Gzip` parameter to `false` while initializing the SDK, as shown:

```ruby
analytics = RudderAnalyticsSync::Client.new(
  write_key: 'WRITE_KEY', # required
  data_plane_url: 'DATA_PLANE_URL',
  stub: false,
  gzip: false, // Set to true to enable Gzip compression
  on_error: proc { |error_code, error_body, exception, response|
    # defaults to an empty proc
  }
)
```

| Note: Gzip requires `rudder-server` version 1.4 or later. |
| :-----|

## Sending events

Refer to the [RudderStack Ruby SDK documentation](https://www.rudderstack.com/docs/sources/event-streams/sdks/rudderstack-ruby-sdk-sync/) for more information on the supported event types.

| From version 2.0.0, the Ruby SDK supports [`screen`](https://www.rudderstack.com/docs/event-spec/standard-events/screen/) events. |
| :-----|

### Manually batching events

You can manually batch your events using `analytics.batch`, as shown:

```ruby
analytics.batch do |batch|
  batch.context = {...}       # Shared context for all the events
  batch.integrations = {...}  # Shared integrations hash for all the events
  batch.identify(...)
  batch.track(...)
  batch.track(...)
  ...
end
```

## License

The RudderStack Ruby SDK is released under the [MIT license](https://github.com/rudderlabs/rudder-sdk-ruby-sync/blob/feat/latest-pull/LICENSE.txt).
