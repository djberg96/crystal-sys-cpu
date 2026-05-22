require "./spec_helper"

describe System::CPU do
  it "defines a version constant" do
    System::CPU::VERSION.should eq("0.2.0")
  end
end
