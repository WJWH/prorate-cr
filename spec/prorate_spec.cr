require "./spec_helper"

describe Prorate do
  # TODO: Write more tests

  it "works" do
    true.should eq(true)
  end
  
  context "CURRENT_SCRIPT_HASH" do
    it "should be the SHA1 hash of the LUA script" do
      script_path = File.join(__DIR__, "../src/prorate/rate_limit.lua")
      script = File.read(script_path)
      Prorate::CURRENT_SCRIPT_HASH.should eq(Digest::SHA1.hexdigest(script))
    end
  end
  
  context "adding identifiers" do   
    it "remembers identifiers added in order" do
      t = Prorate::Throttle.new(name: "test", bucket_capacity: 10, leak_rate: 10, block_for: 120)
      t << "foo"
      t << "bar"
      t << "hatch"
      t.discriminators.should eq(["foo", "bar", "hatch"])
    end
  end
  
  context "Throttled exception" do
    it "carries around the time until the action becomes unblocked" do
      e = Prorate::Throttled.new(10)
      e.retry_in_seconds.should eq(10)
      e.message.should contain("10")
    end
  end
end

