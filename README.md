<p align="center">
  <a href="https://rudderstack.com/">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/rudderlabs/rudder-sdk-js/develop/assets/rs-logo-full-dark.png">
      <img alt="RudderStack" width="512" src="https://raw.githubusercontent.com/rudderlabs/rudder-sdk-js/develop/assets/rs-logo-full-light.jpg">
    </picture>
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

<p align="center"><a href="https://deepwiki.com/rudderlabs/rudder-sdk-ruby-sync"><img src="https://deepwiki.com/badge.svg" alt="Ask DeepWiki"/></a></p>

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

## Retry behavior

Retries are disabled by default to preserve existing synchronous request behavior. You can enable a limited retry budget for HTTP `429`, HTTP `5xx`, and temporary network failures. When enabled, the SDK uses bounded exponential backoff with jitter and honors numeric and HTTP-date `Retry-After` headers.

Retries block the calling thread until delivery succeeds or the retry budget is exhausted. A retry after an ambiguous network failure can also deliver the same event more than once.

Configure retry behavior when you create the client:

```ruby
analytics = RudderAnalyticsSync::Client.new(
  write_key: 'WRITE_KEY',
  retry_enabled: true,
  max_retries: 3,          # Set to 0 to disable retries
  retry_base_delay: 0.1,   # Seconds
  max_retry_delay: 30,     # Seconds, including Retry-After
  retry_jitter_ratio: 0.2,
  respect_retry_after: true
)
```

`retries` is also accepted as a total-attempt count. For example, `retries: 4` permits one initial attempt and three retries.

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

## Releasing

Maintainers must use the automated release process in [RELEASING.md](RELEASING.md).

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
