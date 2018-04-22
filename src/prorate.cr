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
    
    def initialize(@name : String)
      @discriminators = [] of String
    end

    def <<(discriminator : String)
      @discriminators << discriminator
    end

    def throttle!()
      digest = Digest::SHA1.hexdigest(@discriminators.join(""))
      identifier = [name, digest].join(":")
      redis.evalsha(CURRENT_SCRIPT_HASH, [] of String, [identifier, bucket_capacity, leak_rate, block_for])
    end

  end
end
