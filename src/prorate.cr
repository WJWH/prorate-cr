require "./prorate/*"
require "redis"
require "digest"

# TODO: Write documentation for `Prorate`
module Prorate
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
    def initialize(throttle)
      @name = name
      @discriminators = [] of String
    end

    def <<(discriminator)
      @discriminators << discriminator
    end

    def throttle!()
      digest = Digest::SHA1.hexdigest(@discriminators.join(""))
      identifier = [name, digest].join(":")
      redis.evalsha(CURRENT_SCRIPT_HASH, [] of String, [identifier, bucket_capacity, leak_rate, block_for])
    end

  end
end
