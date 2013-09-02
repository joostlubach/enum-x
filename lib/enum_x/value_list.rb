class EnumX

  # A list of multiple enum values.
  class ValueList

    ######
    # Initialization

      def initialize(enum, values)
        @enum = enum
        @values = Array.wrap(values).map { |value| @enum[value] || value }
      end

    ######
    # Attributes

      attr_reader :enum

      attr_reader :values

    ######
    # Method delegation

      # Delegate everything to Array, except querying methods

      # Obtains an array version of the enum.
      alias :to_ary :values

      # Converts the enum to an array of {Enum::Value}s.
      alias :to_a :values

      delegate :to_s, :to => :values

      include Enumerable
      delegate *Array.instance_methods - Object.instance_methods, :to => :values

      def [](value)
        values.find { |val| val.to_s == value.to_s }
      end

      def include?(value)
        values.any? { |val| val.to_s == value.to_s }
      end

      def ==(other)
        case other
        when Array then values == other
        when Enum::ValueList then values == other.values
        when Enum::Value then values == [ other ]
        else false
        end
      end


  end

end