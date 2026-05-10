require "./spec_helper"

{% if flag?(:linux) %}
  describe System::CPU do
    it "exposes processors" do
      processors = System::CPU.processors
      processors.should_not be_empty
      processors.first.members.should_not be_empty
    end

    it "supports dynamic processor attribute access" do
      processor = System::CPU.processors.first
      processor.members.each do |member|
        processor[member].to_s.should be_a(String)
      end
    end

    it "returns load averages" do
      load_avg = System::CPU.load_avg
      load_avg.size.should eq(3)
    end

    it "returns cpu stats" do
      stats = System::CPU.cpu_stats
      stats.should be_a(Hash(String, Array(Int64)))
      stats.values.first.size.should be >= 4
    end

    it "returns a model and frequency" do
      System::CPU.model.should be_a(String)
      System::CPU.freq.should be_a(Int32)
    end

    it "samples cpu usage" do
      usage = System::CPU.cpu_usage(sample_time: 0.1, samples: 1)
      usage.should_not be_nil
      usage.not_nil!.should be >= 0
      usage.not_nil!.should be <= 100
    end
  end
{% end %}
