# Utility class representing an enumeration of options to choose from. This can be used
# in models to make a field have a certain number of allowed options.
#
# Enums are defined in configuration files which are loaded from load paths (see {.load_paths}).
#
# == Enum file format
#
# Enum files are YAML files defining enumerations in the following format:
#
#   <name>: [ <value>, <value, ... ]
#
# E.g.
#
#   statuses: [ draft, sent, returned ]
#
# == Extra formats
#
# Enum values are designed to be converted to various formats. By default, they simply support a name,
# which is the value you specify in the YAML files. They also respond to any method starting with
# 'to_', e.g. +to_string+, +to_json+, +to_legacy+. These return the name of the value, unless otherwise
# specified explicitly when being defined.
#
# If you want to provide extra formats in the YAML, you may indicate them as follows:
#
#   statuses: [ { value: 'draft', legacy: 'new' }, sent, { value: 'returned', legacy: 'back' } ]
#
# Now, the following will all be true:
#
#   Enum.statuses[:draft].value == 'draft'
#   Enum.statuses[:draft].symbol == :draft
#   # => #symbol always returns the value converted to a Symbol
#   Enum.statuses[:draft].to_legacy == 'new'
#   Enum.statuses[:sent].value == 'sent'
#   Enum.statuses[:sent].symbol == :sent
#   Enum.statuses[:sent].to_legacy == 'sent'
#   # => because no explicit value for the 'legacy' format was specified
class EnumX

  autoload :DSL, 'enum_x/dsl'
  autoload :Value, 'enum_x/value'
  autoload :ValueList, 'enum_x/value_list'

  ######
  # Enum retrieval

    class << self

      # An array of Enum load paths.
      #
      # @example Add some enum load paths
      #   Enum.load_paths += Dir[ Rails.root + 'config/enums/**/*.yml' ]
      def load_paths=(paths)
        @load_paths = Array.wrap(paths)
      end
      def load_paths
        @load_paths ||= []
      end

      # Defines a new enum with the given values.
      # @see Enum#initialize
      def define(name, values)
        registry[name] = new(name, values)
      end

      # Undefines an enum.
      def undefine(name)
        registry.delete name
      end

      # Retrieves an enum by name.
      def [](name)
        load_enums unless @registry
        registry[name]
      end

      # Allows overriding of the load handler.
      #
      # Specify an object that responds to +load_enums_from(file, file_type)+ where +file+
      # is a file name, and +file_type+ is either +:yaml+ or +:ruby+. Alternatively, a block
      # may be specified that will receive these parameters.
      #
      # The method does not have to return anything, but should use calls to {define} to
      # actually define the enums.
      #
      # By default, the loader parses the YAML file as a flat Hash, where the keys are enum
      # names, and the values are arrays containing the values.
      #
      # == Usage
      #
      #   Enum.loader = proc do |file, file_type|
      #     if file_type == :ruby
      #       load file
      #     else
      #       ... # Process the YAML file here.
      #     end
      #   end
      attr_accessor :loader

      private

        # @!attribute [r] registry
        # @return [Hash] All defined enums.
        def registry
          @registry ||= HashWithIndifferentAccess.new
        end

        # Tries to look for an enum by the given name.
        #
        #   Enum.statuses == Enum[:statuses]
        def method_missing(method, *args, &block)
          if enum = self[method]
            enum
          elsif method =~ /^to_/
            super
          else
            raise NameError, "enum #{method} not found"
          end
        end

        # Loads enums from the defined load paths.
        def load_enums
          load_paths.each do |path|
            file_type = case path
            when /\.rb$/ then :ruby
            when /\.ya?ml$/ then :yaml
            else :other
            end

            case loader
            when Proc
              loader.call(path, file_type)
            when Has[:load_enums_from]
              loader.load_enums_from(path, file_type)
            else
              case file_type
              when :ruby
                load path
              when :yaml
                load_enums_from_yaml(path)
              else
                # ignore the file
              end
            end
          end
        end

        # Load enums from a YAML file.
        def load_enums_from_yaml(file)
          yaml = YAML.load_file(file)
          yaml.each do |name, values|
            define name, values
          end
        end

    end

  ######
  # Initialization

    # Initializes a new Enum instance.
    #
    # @param [#to_s] name
    #   The name of the enum. This is used to load translations. See {Enum::Value#to_s}.
    # @param [Enumerable] values
    #   The values for the enumeration. Each item is passed to {Enum::Value.new}.
    def initialize(name, values)
      @name = name.to_s

      @values = ValueHash.new
      values.each do |value|
        add_value!(value)
      end
    end

  ######
  # Attributes

    # Make the enum enumerable. That's the least it should do! Also pass on 'join' to the values.
    include Enumerable
    delegate *Array.instance_methods - Object.instance_methods, :to => :values
    delegate :[], :to => :@values

    # @!attribute [r] name
    # @return [String] The name of the enum.
    attr_reader :name

    # @!attribute [r] values
    # @return [Array<Enum::Value>] All allowed enum values.
    def values
      @values.values
    end

    # Obtains an array version of the enum.
    alias :to_ary :values

    # Converts the enum to an array of {Enum::Value}s.
    alias :to_a :values

  ######
  # Operations

    # Creates a duplicate of this enum.
    def dup
      Enum.new(name, values)
    end

    # Creates a clone of this enumeration but without the given values.
    def without(*values)
      Enum.new(name, self.values.reject{|v| values.include?(v)})
    end

    # Creates a duplicate of this enumeration but with only the given values.
    def only(*values)
      Enum.new(name, self.values.select{|v| values.include?(v)})
    end

    # Adds the given values to the enum
    def extend!(*values)
      values.each { |value| add_value!(value) }
    end

  ######
  # Translation

    # The I18n scope for this enum. Override this to provide customization.
    # Default: +enums.<name>+
    def i18n_scope
      [ :enums, name ]
    end

  ######
  # Find method

    # Finds an enum with the given name on a class.
    # TODO: Spec
    def self.find(klass, name)
      return nil unless klass

      enum = klass.send(name) if klass.respond_to?(name) rescue nil
      enum if enum.is_a?(Enum)
    end

  ######
  # ValueHash class

    # A hash for enum values. This is a regular HashWithIndifferentAccess, except that it
    # *really* has indifferent access, also integers are possible as keys.
    class ValueHash < HashWithIndifferentAccess
      def [](key)
        super key.to_s
      end
    end

  ######
  # Symbol & string extension

    # Extend Symbol and String's == and === method to match equal enum values as well
    Symbol.class_eval do
      def triple_equals_with_enums(arg)
        if arg.is_a?(Enum::Value)
          triple_equals_without_enums arg.symbol
        elsif arg.is_a?(Enum::ValueList)
          arg.include?(self)
        else
          triple_equals_without_enums arg
        end
      end
      def double_equals_with_enums(arg)
        if arg.is_a?(Enum::Value)
          double_equals_without_enums arg.symbol
        else
          double_equals_without_enums arg
        end
      end

      alias :triple_equals_without_enums :===
      alias :=== :triple_equals_with_enums
      alias :double_equals_without_enums :==
      alias :== :double_equals_with_enums
    end

    String.class_eval do
      def triple_equals_with_enums(arg)
        if arg.is_a?(Enum::Value)
          triple_equals_without_enums arg.value
        elsif arg.is_a?(Enum::ValueList)
          arg.include?(self)
        else
          triple_equals_without_enums arg
        end
      end
      def double_equals_with_enums(arg)
        if arg.is_a?(Enum::Value)
          double_equals_without_enums arg.value
        else
          double_equals_without_enums arg
        end
      end

      alias :triple_equals_without_enums :===
      alias :=== :triple_equals_with_enums
      alias :double_equals_without_enums :==
      alias :== :double_equals_with_enums
    end

  private

    # Add a new value to the enum values list
    def add_value!(value)
      value = case value
                when Value then value.dup(self)
                else Value.new(self, value)
              end
      @values[value.value] = value
    end
end