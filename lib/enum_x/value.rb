class EnumX

  # One enum value. Each value has a name and may contain any format-specific values.
  class Value

    ######
    # Initialization

      # Initializes a new enum value.
      #
      # @param [EnumX] enum  The owning enum.
      # @param [Hash|#to_s] value
      #   The actual value. If a Hash is specified, it must contain a key 'value' or :value, and may
      #   contain values for any other format.
      #
      # == Examples
      #   EnumX::Value.new(enum, 'new')
      #   EnumX::Value.new(enum, {:value => 'new', :xml => '<new>'})
      def initialize(enum, value)
        raise ArgumentError, "enum required" unless enum
        @enum  = enum

        @formats = {}
        case value
        when Hash
          process_hash(value)
        else
          @value = value.to_s
        end
      end

      # Processes a value hash.
      def process_hash(hash)
        hash = hash.dup

        value = hash.delete(:value) || hash.delete('value')
        raise ArgumentError, "key :value is required when a hash value is specified" unless value

        @value = value.to_s

        # Process all other options as formats.
        hash.each do |key, value|
          @formats[key.to_s] = value
        end
      end

    ######
    # Attributes

      # @!attribute [r] enum
      # @return [EnumX] The EnumX defining this value.
      attr_reader :enum

      # @!attribute [r] value
      # @return [String] The actual string value.
      attr_reader :value

      # @!attribute [r] formats
      # @return [Hash] Any other formats supported by this value.
      attr_reader :formats

      # @!attribute [r] symbol
      # @return [Symbol] The value symbol.
      def symbol
        value.to_sym
      end

    ######
    # Duplication

      # Creates a duplicate of this enum value.
      # @param [EnumX] enum  A new owner enum of the value.
      # @return [EnumX::Value]
      def dup(enum = self.enum)
        Value.new(enum, @formats.merge(:value => value))
      end

    ######
    # Value retrievers

      alias :to_str :value
      alias :to_s :value
      alias :to_sym :symbol

      # Pass numeric conversion to the string value.
      def to_i; value.to_i end
      def to_f; value.to_f end

      def respond_to?(method)
        if method =~ /^to_/ && !%w[ to_int to_a to_ary ].include?(method.to_s)
          true
        elsif method =~ /\?$/ && enum.values.include?($`)
          true
        else
          super
        end
      end

      def method_missing(method, *args, &block)
        if method =~ /^to_/ && !%w[ to_int to_a to_ary ].include?(method.to_s)
          @formats[$'] || value
        elsif method =~ /\?$/
          value = $`

          if enum.values.include?(value)
            # If the owning enum defines the requested value, we treat this as an mnmenonic. Test if this
            # is the current value.
            self == value
          else
            # If the owning enum does not define the requested value, we treat this as a missing method.
            super
          end
        else
          super
        end
      end
      private :method_missing

    ######
    # I18n

      def translate(options = {})
        default_value = if defined?(ActiveSupport)
          ActiveSupport::Inflector.humanize(to_s).downcase
        else
          to_s
        end
        I18n.translate value, options.merge(:scope => @enum.i18n_scope, :default => default_value)
      end
      def translate!(options = {})
        I18n.translate value, options.merge(:scope => @enum.i18n_scope, :raise => true)
      end

    ######
    # Common value object handling

      def ==(other)
        return false if other.nil?
        value == other.to_s
      end

      def eql?(other)
        return false if other.nil?
        other.is_a?(EnumX::Value) && other.enum == enum && other.value == value
      end

      def hash
        value.hash
      end

      def as_json(*args)
        value
      end

      # EnumX values are simply stored as their string values.
      def encode_with(coder)
        coder.tag = nil
        coder.scalar = value
      end

  end

end