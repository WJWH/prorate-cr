require "./prorate/*"
require "redis"
require "digest"

# TODO: Write documentation for `Prorate`
module Prorate  
  class Throttled < Exception
    getter retry_in_seconds : Int32
    def initialize(try_again_in)
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

  def self.get_script_hash
    script_filepath = File.join(__DIR__,"prorate","rate_limit.lua")
    script = File.read(script_filepath)
    Digest::SHA1.hexdigest(script)
  end

  CURRENT_SCRIPT_HASH = get_script_hash

  class Throttle
    getter discriminators
    
    def initialize(name : String, bucket_capacity : Int32, leak_rate : Int32, block_for : Int32)
      @name = name
      @bucket_capacity = bucket_capacity
      @leak_rate = leak_rate
      @block_for = block_for
      @discriminators = [] of String
    end

    def <<(discriminator : String)
      @discriminators << discriminator
    end

    def throttle!()
      digest = Digest::SHA1.hexdigest(@discriminators.join(""))
      identifier = [name, digest].join(":")
      remaining_block_time, bucket_level = redis.evalsha(CURRENT_SCRIPT_HASH, [] of String, [identifier, bucket_capacity, leak_rate, block_for])
      raise Throttled.new(remaining_block_time) if remaining_block_time > 0
    rescue ex : Redis::Error
      if e.message.include? "NOSCRIPT"
        # The Redis server has never seen this script before. Needs to run only once in the entire lifetime of the Redis server (unless the script changes)
        script_filepath = File.join(__DIR__,"prorate","rate_limit.lua")
        script = File.read(script_filepath)
        raise ScriptHashMismatch if Digest::SHA1.hexdigest(script) != CURRENT_SCRIPT_HASH
        redis.script_load(script)
        redis.evalsha(CURRENT_SCRIPT_HASH, [] of String, [identifier, bucket_capacity, leak_rate, block_for])
      else
        raise e
      end
    end

  end
end
