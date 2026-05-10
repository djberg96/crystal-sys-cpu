module System
  module CPU
    extend self

    CPU_INFO_PATH = "/proc/cpuinfo"
    CPU_STAT_PATH = "/proc/stat"
    LOAD_AVG_PATH = "/proc/loadavg"

    @@processors_cache : Array(Processor)? = nil

    def processors : Array(Processor)
      cached_processors.dup
    end

    def processors(& : Processor ->) : Nil
      cached_processors.each do |processor|
        yield processor
      end
    end

    def num_cpu : Int32
      cached_processors.size
    end

    def architecture : String
      case self["cpu_family"]?.try(&.to_s)
      when "3"
        "x86"
      when "4"
        "i486"
      when "5"
        "Pentium"
      when "6"
        "x86_64"
      when "15"
        "Netburst"
      else
        "Unknown"
      end
    end

    def model : String
      string_attribute("model_name", "model", "cpu", "processor")
    end

    def freq : Int32
      self["cpu_mhz"]?.try(&.to_s.to_f.round.to_i) || 0
    end

    def load_avg : Array(Float64)
      File.read(LOAD_AVG_PATH).split[0, 3].map(&.to_f)
    rescue ex
      raise Error.new("Unable to read #{LOAD_AVG_PATH}: #{ex.message}")
    end

    def cpu_stats : Hash(String, Array(Int64))
      stats = {} of String => Array(Int64)
      lines = File.read_lines(CPU_STAT_PATH)

      lines.each_with_index do |line, index|
        fields = line.split
        break unless fields.first?.try(&.starts_with?("cpu"))

        if fields[0] == "cpu"
          next_key = lines[index + 1]?.try(&.split.first?)
          next if next_key && next_key.matches?(/^cpu\d+$/)
        end

        stats[fields[0]] = fields[1..].map(&.to_i64)
      end

      stats
    rescue ex
      raise Error.new("Unable to read #{CPU_STAT_PATH}: #{ex.message}")
    end

    def cpu_usage(*, sample_time : Number? = 1.0, samples : Int? = 2) : Float64?
      sample_time_value = sample_time && sample_time > 0 ? sample_time.to_f : 1.0
      samples_value = samples && samples > 0 ? samples : 2
      usages = [] of Float64

      samples_value.times do
        before = cpu_stats
        blocking_sleep(sample_time_value)
        after = cpu_stats

        total_diff = 0.0
        idle_diff = 0.0
        keys = before.has_key?("cpu") ? ["cpu"] : before.keys

        keys.each do |key|
          prior = before[key]?
          current = after[key]?
          next unless prior && current

          total_diff += current.sum - prior.sum
          idle_diff += (current[3]? || 0_i64) - (prior[3]? || 0_i64)
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

    def [](name : String, cpu_index : Int = 0) : AttributeValue
      processor = cached_processors[cpu_index]? || raise IndexError.new("No CPU at index #{cpu_index}")
      processor.fetch_attribute(name)
    end

    def []?(name : String, cpu_index : Int = 0) : AttributeValue?
      cached_processors[cpu_index]?.try(&.[]?(name))
    end

    private def cached_processors : Array(Processor)
      @@processors_cache ||= load_processors
    end

    private def load_processors : Array(Processor)
      records = [] of Processor
      current = {} of String => AttributeValue

      File.each_line(CPU_INFO_PATH) do |raw_line|
        line = raw_line.strip
        next if line.empty?

        key, value = line.split(":", 2)
        normalized_key = normalize_key(key)

        if current.has_key?(normalized_key)
          records << Processor.new(current.dup)
          current.clear
        end

        current[normalized_key] = normalize_value(value)
      end

      records << Processor.new(current) unless current.empty?
      records
    rescue ex
      raise Error.new("Unable to parse #{CPU_INFO_PATH}: #{ex.message}")
    end

    private def normalize_key(key : String) : String
      key.strip.downcase.gsub(/\s+/, "_")
    end

    private def normalize_value(value : String?) : AttributeValue
      normalized = value.to_s.strip

      case normalized
      when "yes"
        true
      when "no"
        false
      when ""
        nil
      else
        normalized
      end
    end

    private def string_attribute(*names : String) : String
      names.each do |name|
        value = self[name]?
        return value if value.is_a?(String)
      end

      ""
    end
  end
end
