# Prorate

Prorate is a throttling/rate limiting library based on the [Leaky Bucket algorithm](https://en.wikipedia.org/wiki/Leaky_bucket) implemented as a Lua script in Redis. This enables coordinated throttling of traffic coming into many different web servers, which is much more tricky with an in-process implementation. The algorithm is designed in such a way as to keep Redis memory use as minimal as possible.

There is also a Ruby variant of Prorate available [here](https://github.com/WeTransfer), made and maintained by the lovely people at WeTransfer.

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  prorate:
    github: wjwh/prorate
```

## Usage

This shard defines a method called `with_throttle!` that you can use to rate limit almost anything. For example to limit the rate at which any IP can call the `/login` endpoint in a kemal application you can use something like the following:

```crystal
require "prorate"
require "kemal"

post "/login" do |env|
  with_throttle(name: "login-throttle", bucket_capacity: 3, leak_rate: 0.1, block_for: 10) do |t|
    t << env.request.remote_ip
  end
  # rest of login logic here
rescue Prorate::Throttled
  halt env, status_code: 429, response: "Too many login attempts in short succession."
end
```

This sets up a throttle that will allow up to three requests in quick succession. However, after three request the "bucket" is full and further requests will overflow it, leading to a `Prorate::Throttled` exception being raised for this request and any further requests within `block_for` seconds. The bucket will only drain at a rate of one request per ten seconds, the `leak_rate`, so that is the maximum rate of requests that can be sustained without running into the `Prorate::Throttled` exception. This way you can allow for a user eg mistyping their password once or twice without hitting the lockout, but can still make sure that brute force attacks are not feasible.

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
