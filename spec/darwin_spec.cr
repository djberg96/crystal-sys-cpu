require "./spec_helper"

{% if flag?(:darwin) %}
  describe System::CPU do
    it "returns basic system information" do
      System::CPU.architecture.should be_a(String)
      System::CPU.machine.should be_a(String)
      System::CPU.model.should be_a(String)
      System::CPU.num_cpu.should be > 0
    end

    it "returns a 3-element load average" do
      load_avg = System::CPU.load_avg
      load_avg.size.should eq(3)
    end

    it "samples cpu usage" do
      usage = System::CPU.cpu_usage(sample_time: 0.1, samples: 1)
      usage.should_not be_nil
      usage.not_nil!.should be >= 0
      usage.not_nil!.should be <= 100
    end

    it "returns a frequency when the platform exposes one" do
      value = System::CPU.freq
      (value.nil? || value.is_a?(Int32)).should be_true
    end
  end
{% end %}
