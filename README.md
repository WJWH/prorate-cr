# Prorate

BE AWARE, this library is still being worked on and should not be used for anything seriously yet.

Prorate is a throttling/rate limiting library based on the [Leaky Bucket algorithm](https://en.wikipedia.org/wiki/Leaky_bucket) implemented as a Lua script in Redis. This enables coordinated throttling of traffic coming into many different web servers, which is much more tricky with an in-process implementation. The algorithm is designed in such a way as to keep Redis memory use as minimal as possible.

There is also a Ruby variant of Prorate available [here](https://github.com/WeTransfer), made and maintained by the lovely people at WeTransfer.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  prorate:
    github: [your-github-name]/prorate
```

## Usage

```crystal
require "prorate"
```

TODO: Write usage instructions here

## Development

Running the test suite requires a running Redis server. By default it will try the default location (ie `localhost:6379`), but you can override this by supplying a `REDIS_URL` environment variable if you want to test against a redis server in another location.

## Contributing

1. Fork it ( https://github.com/[your-github-name]/prorate/fork )
2. Create your feature branch (git checkout -b my-new-feature)
3. Commit your changes (git commit -am 'Add some feature')
4. Push to the branch (git push origin my-new-feature)
5. Create a new Pull Request

## Contributors

- [wjwh](https://github.com/wjwh) Wander Hillen - creator, maintainer
