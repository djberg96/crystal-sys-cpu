module System
  module CPU
    class Processor
      getter attributes : Hash(String, AttributeValue)

      def initialize(@attributes : Hash(String, AttributeValue))
      end

      def [](name : String) : AttributeValue
        fetch_attribute(name)
      end

      def []?(name : String) : AttributeValue?
        @attributes[name]?
      end

      def members : Array(String)
        @attributes.keys
      end

      def to_h : Hash(String, AttributeValue)
        @attributes.dup
      end

      def fetch_attribute(name : String) : AttributeValue
        @attributes[name]? || raise KeyError.new("Unknown CPU attribute: #{name}")
      end

      macro method_missing(call)
        {% if call.args.empty? && call.block.nil? %}
          fetch_attribute({{call.name.stringify}})
        {% else %}
          {% raise "Processor dynamic attribute access only supports zero-argument calls" %}
        {% end %}
      end
    end
  end
end
