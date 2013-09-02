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

      # Converts the enum to an array of {EnumX::Value}s.
      alias :to_a :values

      # Creates a string representation of the values.
      def to_s
        values.map(&:to_s).join(', ')
      end

      include Enumerable

      # Create delegate methods for all of Enumerable's own methods.
      Enumerable.instance_methods.each do |method|
        class_eval <<-RUBY, __FILE__, __LINE__+1
          def #{method}(*args, &block)
            values.__send__ :#{method}, *args, &block
          end
        RUBY
      end

      def [](value)
        values.find { |val| val.to_s == value.to_s }
      end

      def include?(value)
        values.any? { |val| val.to_s == value.to_s }
      end

      def ==(other)
        case other
        when Array then values == other
        when EnumX::ValueList then values == other.values
        when EnumX::Value then values == [ other ]
        else false
        end
      end


  end

end