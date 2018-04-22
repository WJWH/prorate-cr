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
  
end

