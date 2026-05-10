@[Link("c")]
lib SystemCPUDarwin
  alias SizeT = LibC::SizeT

  struct ClockInfo
    hz : Int32
    tick : Int32
    spare : Int32
    stathz : Int32
    profhz : Int32
  end

  fun sysctlbyname(name : UInt8*, oldp : Void*, oldlenp : SizeT*, newp : Void*, newlen : SizeT) : Int32
  fun getloadavg(loadavg : Float64*, nelem : Int32) : Int32
  fun mach_host_self : UInt32
  fun host_statistics(host_priv : UInt32, flavor : Int32, host_info_out : UInt32*, host_info_outCnt : UInt32*) : Int32
end

module System
  module CPU
    extend self

    HOST_CPU_LOAD_INFO       = 3
    HOST_CPU_LOAD_INFO_COUNT = 4

    @@hardware_overview : Hash(String, String)? = nil

    # Returns the machine architecture string, such as "arm64".
    def architecture : String
      read_string_sysctl("hw.machine")
    end

    # Darwin exposes the machine class through the same sysctl we use for architecture.
    def machine : String
      read_string_sysctl("hw.machine")
    end

    # Returns the number of logical CPUs reported by the kernel.
    def num_cpu : Int32
      read_scalar_sysctl("hw.ncpu", Int32)
    end

    # Returns the most descriptive CPU or chip name that macOS will give us.
    def model : String
      brand = read_optional_string_sysctl("machdep.cpu.brand_string")
      return brand unless brand.empty?

      chip = hardware_overview["Chip"]? || hardware_overview["Processor Name"]?
      return chip if chip

      case read_optional_scalar_sysctl("hw.cputype", Int32)
      when 7, 0x01000007
        "Intel"
      when 12, 0x0100000c
        "ARM"
      when 14
        "SPARC"
      when 18, 0x01000012
        "PowerPC"
      else
        "Unknown"
      end
    end

    # Returns CPU frequency in MHz when the platform exposes it.
    def freq : Int32?
      hz = read_optional_scalar_sysctl("hw.cpufrequency", Int64)
      return (hz / 1_000_000).to_i if hz && hz > 0

      if architecture.starts_with?("arm")
        tbfrequency = read_optional_scalar_sysctl("hw.tbfrequency", Int64)
        clock = read_clock_info?

        if tbfrequency && tbfrequency > 0 && clock
          return ((tbfrequency * clock.hz) / 1_000_000).to_i
        end
      end

      nil
    end

    # Returns the 1, 5, and 15 minute load averages.
    def load_avg : Array(Float64)
      values = Pointer(Float64).malloc(3_u64)
      result = SystemCPUDarwin.getloadavg(values, 3)
      raise Error.new("getloadavg failed") if result < 0

      [values[0], values[1], values[2]]
    end

    # Returns the current CPU usage as a percentage, averaged over a sampling interval.
    #
    # By default, this method samples CPU usage over a 1-second interval and
    # averages two measurements. You can customize the interval and number of
    # samples by passing the `sample_time` (in seconds) and `samples` keyword
    # arguments. For example, `cpu_usage(sample_time: 0.5, samples: 4)` takes
    # four samples, each 0.5 seconds apart, and returns the average CPU usage
    # over that period.
    #
    # Passing `nil`, `0`, or a negative value for either argument falls back to
    # the defaults (`1.0` seconds and `2` samples) to keep behavior consistent
    # across platforms.
    #
    # Returns a `Float64` percentage rounded to one decimal place, or `nil` if
    # CPU usage cannot be determined.
    #
    # Example usage:
    #   System::CPU.cpu_usage                               # => 12.3
    #   System::CPU.cpu_usage(sample_time: 2, samples: 3)  # => 10.7
    #   System::CPU.cpu_usage(sample_time: 0, samples: 0)  # => 12.3
    def cpu_usage(*, sample_time : Number? = 1.0, samples : Int? = 2) : Float64?
      sample_time_value = sample_time && sample_time > 0 ? sample_time.to_f : 1.0
      samples_value = samples && samples > 0 ? samples : 2
      usages = [] of Float64

      samples_value.times do
        before = current_ticks
        blocking_sleep(sample_time_value)
        after = current_ticks

        total_diff = 0.0
        idle_diff = 0.0

        after.each_with_index do |value, index|
          delta = value - before[index]
          total_diff += delta
          idle_diff += delta if index == 2
        end

        if total_diff > 0
          usages << ((1.0 - (idle_diff / total_diff)) * 100.0)
        end
      end

      return nil if usages.empty?

      (usages.sum / usages.size).round(1)
    rescue
      nil
    end

    # Reads aggregate CPU tick counters from Mach host statistics.
    private def current_ticks : Array(UInt32)
      host = SystemCPUDarwin.mach_host_self
      info = StaticArray(UInt32, HOST_CPU_LOAD_INFO_COUNT).new(0_u32)
      count = HOST_CPU_LOAD_INFO_COUNT.to_u32
      result = SystemCPUDarwin.host_statistics(host, HOST_CPU_LOAD_INFO, info.to_unsafe, pointerof(count))
      raise Error.new("host_statistics failed") unless result == 0

      info.to_a
    end

    # Used only for the ARM fallback frequency calculation.
    private def read_clock_info? : SystemCPUDarwin::ClockInfo?
      clock = uninitialized SystemCPUDarwin::ClockInfo
      size = LibC::SizeT.new(sizeof(SystemCPUDarwin::ClockInfo))
      result = SystemCPUDarwin.sysctlbyname("kern.clockrate", pointerof(clock).as(Void*), pointerof(size), Pointer(Void).null, 0)
      return nil unless result == 0

      clock
    end

    # Raises when a required sysctl string is missing.
    private def read_string_sysctl(name : String) : String
      value = read_optional_string_sysctl(name)
      return value unless value.empty?

      raise Error.new("sysctlbyname failed for #{name}")
    end

    # Performs the two-step sysctl read needed for variable-length strings.
    private def read_optional_string_sysctl(name : String) : String
      size = LibC::SizeT.new(0)
      return "" unless SystemCPUDarwin.sysctlbyname(name, Pointer(Void).null, pointerof(size), Pointer(Void).null, 0) == 0
      return "" if size == 0

      buffer = Bytes.new(size.to_i)
      return "" unless SystemCPUDarwin.sysctlbyname(name, buffer.to_unsafe.as(Void*), pointerof(size), Pointer(Void).null, 0) == 0

      used = size.to_i
      used -= 1 if used > 0 && buffer[used - 1] == 0
      String.new(buffer.to_unsafe, used)
    end

    # Raises when a required fixed-size sysctl value is missing.
    private def read_scalar_sysctl(name : String, type : T.class) : T forall T
      value = read_optional_scalar_sysctl(name, type)
      return value if value

      raise Error.new("sysctlbyname failed for #{name}")
    end

    # Reads typed sysctl scalars such as Int32 and Int64 values.
    private def read_optional_scalar_sysctl(name : String, type : T.class) : T? forall T
      value = uninitialized T
      size = LibC::SizeT.new(sizeof(T))
      result = SystemCPUDarwin.sysctlbyname(name, pointerof(value).as(Void*), pointerof(size), Pointer(Void).null, 0)
      result == 0 ? value : nil
    end

    # Caches a small subset of system_profiler output for human-friendly chip names.
    private def hardware_overview : Hash(String, String)
      @@hardware_overview ||= begin
        output = IO::Memory.new
        error = IO::Memory.new
        Process.run("system_profiler", ["SPHardwareDataType"], output: output, error: error)

        values = {} of String => String

        "#{output}#{error}".each_line do |line|
          next unless match = line.match(/^\s*([^:]+):\s+(.+?)\s*$/)
          values[match[1]] = match[2]
        end

        values
      end
    end
  end
end
