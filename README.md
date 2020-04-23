# What is Rudder?

**Short answer:** 
Rudder is an open-source Segment alternative written in Go, built for the enterprise. .

**Long answer:** 
Rudder is a platform for collecting, storing and routing customer event data to dozens of tools. Rudder is open-source, can run in your cloud environment (AWS, GCP, Azure or even your data-centre) and provides a powerful transformation framework to process your event data on the fly.

Released under [MIT License 2.0](https://opensource.org/licenses/MIT)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rudder_analytics_sync'
```

Or install it yourself as:

```sh
$ gem install rudder_analytics_sync
```

## Usage

Create a client instance:

```ruby
analytics = RudderAnalyticsSync::Client.new(
  write_key: <YOUR_WRITE_KEY>, # required
  data_plane_url: <DATA_PLANE_URL>
  on_error: proc { |error_code, error_body, exception, response|
    # defaults to an empty proc
  }
)
```

Use it as you would use `analytics-ruby`:

```ruby
analytics.track(
  user_id: user.id,
  event: 'Created Account'
)
```

### Batching

You can manually batch events with `analytics.batch`:

```ruby
analytics.batch do |batch|
  batch.context = {...}       # shared context for all events
  batch.integrations = {...}  # shared integrations hash for all events
  batch.identify(...)
  batch.track(...)
  batch.track(...)
  ...
end
```

### Stub API calls

You can stub your API calls avoiding unecessary requests in development and automated test environments (backwards compatible with the official gem):

```ruby
analytics = RudderAnalyticsSync::Client.new(
  write_key: 'YOUR_WRITE_KEY',
  stub: true
)
```

### Configurable Logger

When used in stubbed mode all calls are logged to STDOUT, this can be changed by providing a custom logger object:

```ruby
analytics = RudderAnalyticsSync::Client.new(
  write_key: 'YOUR_WRITE_KEY',
  logger: Rails.logger
)
```

### Set HTTP Options

You can set [options](https://docs.ruby-lang.org/en/2.0.0/Net/HTTP.html#method-c-start) that are passed to `Net::HTTP.start`.

```ruby
analytics = RudderAnalyticsSync::Client.new(
  write_key: 'YOUR_WRITE_KEY',
  http_options: {
    open_timeout: 42,
    read_timeout: 42,
    close_on_empty_response: true,
    # ...
  }
)
```

## Contact Us
If you come across any issues while configuring or using RudderStack, please feel free to [contact us](https://rudderstack.com/contact/) or start a conversation on our [Discord](https://discordapp.com/invite/xNEdEGw) channel. We will be happy to help you.
