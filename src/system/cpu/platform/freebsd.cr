@[Link("c")]
lib SystemCPUFreeBSD
  alias SizeT = LibC::SizeT

  fun sysctlbyname(name : UInt8*, oldp : Void*, oldlenp : SizeT*, newp : Void*, newlen : SizeT) : Int32
  fun getloadavg(loadavg : Float64*, nelem : Int32) : Int32
end

module System
  module CPU
    extend self

    CPU_STATES     = 5
    CPU_STATE_IDLE = 4

    # Returns the machine architecture string, such as "amd64".
    def architecture : String
      arch = read_optional_string_sysctl("hw.machine_arch")
      return arch unless arch.empty?

      read_string_sysctl("hw.machine")
    end

    # Returns the FreeBSD machine class, such as "amd64" or "arm64".
    def machine : String
      read_string_sysctl("hw.machine")
    end

    # Returns the number of logical CPUs reported by the kernel.
    def num_cpu : Int32
      read_scalar_sysctl("hw.ncpu", Int32)
    end

    # Returns the kernel-reported CPU model string.
    def model : String
      read_string_sysctl("hw.model")
    end

    # Returns CPU frequency in MHz when the platform exposes it.
    def freq : Int32?
      current = read_optional_scalar_sysctl("dev.cpu.0.freq", Int32)
      return current if current && current > 0

      nominal = read_optional_scalar_sysctl("hw.clockrate", Int32)
      return nominal if nominal && nominal > 0

      nil
    end

    # Returns the 1, 5, and 15 minute load averages.
    def load_avg : Array(Float64)
      values = uninitialized StaticArray(Float64, 3)
      result = SystemCPUFreeBSD.getloadavg(values.to_unsafe, 3)
      raise Error.new("getloadavg failed") if result < 0

      values.to_a
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
          idle_diff += delta if index == CPU_STATE_IDLE
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

    # Reads aggregate CPU state counters from kern.cp_time.
    private def current_ticks : Array(Int64)
      values = uninitialized StaticArray(LibC::Long, CPU_STATES)
      size = LibC::SizeT.new(sizeof(LibC::Long) * CPU_STATES)
      result = SystemCPUFreeBSD.sysctlbyname("kern.cp_time", values.to_unsafe.as(Void*), pointerof(size), Pointer(Void).null, 0)
      raise Error.new("sysctlbyname failed for kern.cp_time") unless result == 0

      values.to_a.map(&.to_i64)
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
      return "" unless SystemCPUFreeBSD.sysctlbyname(name, Pointer(Void).null, pointerof(size), Pointer(Void).null, 0) == 0
      return "" if size == 0

      buffer = Bytes.new(size.to_i)
      return "" unless SystemCPUFreeBSD.sysctlbyname(name, buffer.to_unsafe.as(Void*), pointerof(size), Pointer(Void).null, 0) == 0

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

    # Reads typed sysctl scalars such as Int32 values.
    private def read_optional_scalar_sysctl(name : String, type : T.class) : T? forall T
      value = uninitialized T
      size = LibC::SizeT.new(sizeof(T))
      result = SystemCPUFreeBSD.sysctlbyname(name, pointerof(value).as(Void*), pointerof(size), Pointer(Void).null, 0)
      result == 0 ? value : nil
    end
  end
end
