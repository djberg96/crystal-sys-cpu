module System
  module CPU
    extend self

    def architecture : String
      raise Error.new("System::CPU is not implemented for this platform yet")
    end

    def machine : String
      raise Error.new("System::CPU is not implemented for this platform yet")
    end

    def num_cpu : Int32
      raise Error.new("System::CPU is not implemented for this platform yet")
    end

    def model : String
      raise Error.new("System::CPU is not implemented for this platform yet")
    end

    def freq
      raise Error.new("System::CPU is not implemented for this platform yet")
    end

    def load_avg
      raise Error.new("System::CPU is not implemented for this platform yet")
    end

    def cpu_usage(*, sample_time : Number? = 1.0, samples : Int? = 2)
      raise Error.new("System::CPU is not implemented for this platform yet")
    end
  end
end
