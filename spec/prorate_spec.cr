require "./spec_helper"

describe Prorate do
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

  context "when using throttle!" do
    Spec.before_each do
      Redis.new.flushall
    end

    it "allows calls if the bucket is not yet full" do
      t = Prorate::Throttle.new(name: "test", bucket_capacity: 10, leak_rate: 10, block_for: 120)
      t << "foo"
      t.throttle!.should be_nil
    end

    it "raises a Throttled exception if the bucket is full" do
      t = Prorate::Throttle.new(name: "test", bucket_capacity: 2, leak_rate: 10, block_for: 120)
      t << "foo"
      expect_raises(Prorate::Throttled) { 3.times { t.throttle! }}
    end

    it "after the cooldown has passed, allows calls again" do
      t = Prorate::Throttle.new(name: "test", bucket_capacity: 2, leak_rate: 10, block_for: 1)
      t << "foo"
      expect_raises(Prorate::Throttled) { 3.times { t.throttle! }}
      sleep 1
      t.throttle!.should be_nil
    end

    it "does not keep redis keys around for longer than necessary" do
      r = Redis.new
      throttle_name = "test"
      t = Prorate::Throttle.new(name: throttle_name, bucket_capacity: 2, leak_rate: 1, block_for: 3)
      t << "foo"

      identifier = Digest::SHA1.hexdigest("foo")
      bucket_key = throttle_name + ":" + identifier + ".bucket_level"
      last_updated_key = throttle_name + ":" + identifier + ".last_updated"
      block_key = throttle_name + ":" + identifier + ".block"

      # At the start all keys should be empty
      r.get(bucket_key).should be_nil
      r.get(last_updated_key).should be_nil
      r.get(block_key).should be_nil

      2.times do
        t.throttle!
      end

      # We are not blocked yet, the bucket keys should be set but no block key
      r.get(bucket_key).should_not be_nil
      r.get(last_updated_key).should_not be_nil
      r.get(block_key).should be_nil
      expect_raises(Prorate::Throttled) { t.throttle! } # tip it over the edge
      # Now the block key should be set as well, and the other two should still be set
      r.get(bucket_key).should_not be_nil
      r.get(last_updated_key).should_not be_nil
      r.get(block_key).should_not be_nil
      sleep 2.2
      # After <bucket_capacity / leak rate> time elapses without anything happening, the
      # keys can be deleted. The block should still be there though
      r.get(bucket_key).should be_nil
      r.get(last_updated_key).should be_nil
      r.get(block_key).should_not be_nil
      sleep 1
      # Now the block should be gone as well
      r.get(bucket_key).should be_nil
      r.get(last_updated_key).should be_nil
      r.get(block_key).should be_nil
    end
  end
  
  context "when using with_throttle!" do
    Spec.before_each do
      Redis.new.flushall
    end
    
    it "allows calls if the bucket is not yet full" do
      Prorate.with_throttle(name: "test", bucket_capacity: 10, leak_rate: 10, block_for: 120) do |t|
        t << "foo"
      end
    end
    
    it "raises if the bucket does not have capacity" do
      expect_raises(Prorate::Throttled) {
        Prorate.with_throttle(name: "test", bucket_capacity: 1, leak_rate: 0.1, block_for: 120) do |t|
          t << "foo"
        end
        Prorate.with_throttle(name: "test", bucket_capacity: 1, leak_rate: 0.1, block_for: 120) do |t|
          t << "foo"
        end
      }
    end
  end
end
