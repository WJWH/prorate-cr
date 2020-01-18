require "./prorate/*"
require "redis"
require "digest"

module Prorate
  class Throttled < Exception
    getter retry_in_seconds : Int64
    def initialize(try_again_in : Int64)
      @retry_in_seconds = try_again_in
      super("Throttled, please lower your temper and try again in #{retry_in_seconds} seconds")
    end
    def message : String
      "Throttled, please lower your temper and try again in #{retry_in_seconds} seconds"
    end
  end

  class ScriptHashMismatch < Exception
  end

  class MisconfiguredThrottle < Exception
  end
  
  class RedisConnectionError < Exception
  end

  def self.get_script_hash
    script_filepath = File.join(__DIR__,"prorate","rate_limit.lua")
    script = File.read(script_filepath)
    Digest::SHA1.hexdigest(script)
  end

  CURRENT_SCRIPT_HASH = get_script_hash

  class Throttle
    getter discriminators
    
    def initialize(name : String, bucket_capacity : Int32, leak_rate : Float32, block_for : Int32, redis : Redis::PooledClient = Redis::PooledClient.new)
      @name = name
      @bucket_capacity = bucket_capacity
      @leak_rate = leak_rate
      @block_for = block_for
      @discriminators = [] of String
      @redis = redis
    end

    def <<(discriminator : String)
      @discriminators << discriminator
    end

    def throttle!
      digest = Digest::SHA1.hexdigest(@discriminators.join(""))
      identifier = [@name, digest].join(":")
      response = @redis.evalsha(CURRENT_SCRIPT_HASH, [] of String, [identifier, @bucket_capacity, @leak_rate, @block_for]).as(Array((Redis::RedisValue)))
      # response is an array shaped like: [remaining_block_time, bucket_level]
      remaining_block_time_64 = response[0].as(Int64)
      raise Throttled.new(remaining_block_time_64) if remaining_block_time_64 > 0
      return nil
    rescue ex : Redis::Error
      if ex.message.as(String).includes? "NOSCRIPT"
        # The Redis server has never seen this script before. Needs to run only once in the entire lifetime of the Redis server (unless the script changes)
        script_filepath = File.join(__DIR__,"prorate","rate_limit.lua")
        script = File.read(script_filepath)
        raise ScriptHashMismatch.new if Digest::SHA1.hexdigest(script) != CURRENT_SCRIPT_HASH
        @redis.script_load(script)
        throttle!
      else
        raise ex
      end
    end
  end

  # A small convenience method:
  def self.with_throttle(name : String, bucket_capacity : Int32, leak_rate : Float32, block_for : Int32)
    t = Prorate::Throttle.new(name: name, bucket_capacity: bucket_capacity, leak_rate: leak_rate, block_for: block_for)
    yield t
    return t.throttle!
  end
end
