class EnumX

  # Mixin for any ActiveRecord or ActiveModel object to support enums.
  #
  # == Usage
  #
  # First, make sure your model class includes +EnumX::DSL+:
  #
  #   include EnumX::DSL
  #
  # Then, define any enum-like attribute using the {#enum} method. The best enum is always
  # inferred. The following are identical:
  #
  #   enum :status, :statuses
  #   enum :status, EnumX.statuses
  #   enum :status, EnumX[:statuses]
  #   enum :status
  #
  # The latter infers the 'statuses' enum by default. If no applicable enum was found, an
  # error is thrown.
  #
  # == Multi-enums
  #
  # Specify the option +:flags => true+ to allow the attribute to contain multiple enum values at
  # once. The attribute will in essence become an array.
  #
  # @see ClassMethods#enum
  module DSL

    def self.included(target)
      target.extend ClassMethods
    end

    ######
    # DSL methods

      module ClassMethods

        # @!method enum(name, [enum], validation_options = {})
        #
        # Defines an enum for an attribute. This works on ActiveRecord objects, but also on other objects. However,
        # for non-ActiveRecord objects, make sure that the underlying attribute already exists.
        #
        # @param [Symbol] attribute  The attribute to add enum support to.
        # @param [EnumX|Enumerable|Symbol]
        #   The enum to use. Specify a symbol to look up the enum from the defined enums, or use
        #   an array to create an ad-hoc enum for this attribute, with name "#{model}_#{attribute.pluralize}",
        #   e.g. 'post_statuses'.
        # @param [Hash] validation_options
        #   Options for the validation routine. The options listed below are extracted from this hash.
        # @option validation_options :validation
        #   Set to false to disable validation altogether. TODO SPEC
        # @option validation_options :flags
        #   Set to true to enable a flag enum attribute.
        # @option validation_options :mnemonics
        #   Set to true to create enum mnemonics on the receiver class. These are question-mark style methods for
        #   all the values on the enum. Note that these may override existing methods, so use them only for enums
        #   that define a part of the 'identity' of the receiving class, such as a status or a kind.
        #
        # @example The following creates an enum on an ActiveRecord object.
        #   enum :kind                     # => Uses EnumX.kinds
        # @example The following creates an enum on an ActiveRecord object, but uses 'account_kinds' as the name.
        #   enum :kind, :account_kinds     # => Uses EnumX.account_kinds
        # @example The following creates an enum on an ActiveRecord object, but uses a custom array.
        #   class Account < ActiveRecord::Base
        #     enum :kind, %w[ normal special ]  # => Uses an on the fly enum with name 'account_kinds'.
        #   end
        # @example The following creates an enum on an ActiveRecord object, but uses a custom array, on an anonymous class.
        #   Class.new(ActiveRecord::Base) do
        #     enum :kind, %w[ normal special ]  # => Uses an on the fly enum with name '_kinds'.
        #   end
        # @example The following creates an enum on a non-ActiveRecord class.
        #   class Account
        #     attr_accessor :kind   # Required first!
        #     enum :kind
        #   end
        #
        # @example The following creates an enum and creates mnemonics.
        #   class Account < ActiveRecord::Base
        #     enum :kind, :mnemonics => true
        #   end
        #
        #   # Given that enum 'kinds' has options %[ normal special ], the following methods are now added:
        #   Account.new(:kind => :normal).normal? # => true
        #   Account.new(:kind => :special).normal? # => true
        #   Account.new(:kind => :normal).special? # => false
        #   Account.new(:kind => :special).special? # => false
        #   Account.new(:kind => :special).something_else? # => raises NoMethodError
        def enum(attribute, *args)

          validation_options = args.extract_options!
          enum = args.shift
          raise ArgumentError, "too many arguments (2..3 expected)" if args.length > 0

          flags = validation_options.delete(:flags)
          mnemonics = validation_options.delete(:mnemonics)

          # Determine the default name of the enum, and the name of the class-level enum reader.
          enum_reader_name = if flags
            # The attribute is already specified in the plural form (enum :statuses).
            attribute.to_s
          else
            # The attribute is specified in the singular form - pluralize it (enum :status).
            attribute.to_s.pluralize
          end

          enum = case enum_opt = enum
          when nil then EnumX[enum_reader_name]
          when EnumX then enum
          when Symbol, String then EnumX[enum]
          when Enumerable
            name = if self.name
              "#{self.name.demodulize.underscore}_#{enum_reader_name}"
            else
              # Anonymous class - use just the attribute name with an underscore in front of it.
              "_#{enum_reader_name}"
            end

            EnumX.new(name, enum)
          end
          raise ArgumentError, "cannot find enum #{(enum_opt || enum_reader_name).inspect}" unless enum

          # Define a shorthand enum accessor method.
          unless respond_to?(enum_reader_name)
            # Regular class. As the class may be inherited, make sure to try superclasses as well.
            class_eval <<-RUBY, __FILE__, __LINE__+1
              def self.#{enum_reader_name}
                @#{enum_reader_name} ||= if superclass.respond_to?(:#{enum_reader_name})
                  superclass.#{enum_reader_name}
                end
              end
            RUBY
          end

          # Store the enum on this class.
          instance_variable_set "@#{enum_reader_name}", enum

          if flags
            # Define a flags enum.

            # Validation
            if validation_options[:validation] != false

              validation_options.assert_valid_keys :allow_blank
              if validation_options[:allow_blank] != false
                class_eval <<-RUBY, __FILE__, __LINE__+1
                  validates_each :#{attribute} do |record, attribute, value|
                    if value.present?
                      value = [ value ] unless value.is_a?(Enumerable)
                      if not_included_value = value.find{ |v| !enum.values.include?(v) }
                        record.errors.add attribute, :inclusion, :value => not_included_value
                      end
                    end
                  end
                RUBY
              else
                class_eval <<-RUBY, __FILE__, __LINE__+1
                  validates_each :#{attribute} do |record, attribute, value|
                    value = [ value ] unless value.is_a?(Enumerable) || value.nil?
                    if value.blank?
                      record.errors.add attribute, :blank
                    elsif not_included_value = value.find{ |v| !enum.values.include?(v) }
                      record.errors.add attribute, :inclusion, :value => not_included_value
                    end
                  end
                RUBY
              end

            end

            # Serialize the value if this is an ActiveRecord class AND if the database actually contains
            # this column.
            if defined?(ActiveRecord) && self < ActiveRecord::Base && self.column_names.include?(attribute.to_s)
              serialize attribute, FlagsSerializer.new(enum)
            end

            # Provide a customized reader.
            DSL.define_multi_reader self, attribute
            DSL.define_multi_writer self, attribute

            # Provide two Squeel sifters.
            if respond_to?(:sifter)
              class_eval <<-RUBY, __FILE__, __LINE__+1
                sifter(:#{attribute}_include) { |value| instance_eval('#{attribute}') =~ "%|\#{value}|%" }
                sifter(:#{attribute}_exclude) { |value| instance_eval('#{attribute}') !~ "%|\#{value}|%" }
              RUBY
            end

          else
            # Define a single enum.

            # Validation
            if validation_options[:validation] != false
              # Provide validations.
              validation_options = validation_options.merge(:in => enum.values)
              validation_options[:allow_blank] = true unless validation_options.key?(:allow_blank)

              validates_inclusion_of attribute, validation_options
            end

            # Serialize the value if this is an ActiveRecord class AND if the database actually contains
            # this column.
            if defined?(ActiveRecord) && self < ActiveRecord::Base && self.column_names.include?(attribute.to_s)
              serialize attribute, SingleSerializer.new(enum)
            end

            # Provide a customized reader.
            DSL.define_single_reader self, attribute
            DSL.define_single_writer self, attribute

          end

          # Provide mnemonics if requested
          DSL.define_mnemonics self, attribute, enum if mnemonics

        end

      end

    ######
    # Generic reader & writer

      # Defines a generic attribute reader ActiveModel-like classes.
      # @api private
      def self.define_reader(target, attribute, body)
        override = target.instance_methods.include?(attribute.to_sym)

        value_reader = case true
        when override
          "#{attribute}_without_enums"
        when target.instance_methods.include?(:read_attribute) || target.private_instance_methods.include?(:read_attribute)
          "read_attribute(:#{attribute})"
        else
          # We need a reader to fall back to.
          raise "cannot overwrite enum reader - no existing reader found"
        end

        body.gsub! '%{read_value}', value_reader

        if override
          target.class_eval <<-RUBY, __FILE__, __LINE__+1
            def #{attribute}_with_enums
              #{body}
            end
            alias_method_chain :#{attribute}, :enums
          RUBY
        else
          target.class_eval <<-RUBY, __FILE__, __LINE__+1
            def #{attribute}
              #{body}
            end
          RUBY
        end
      end

      # Defines a generic attribute writer ActiveModel-like classes.
      # @api private
      def self.define_writer(target, attribute, body)
        method = :"#{attribute}="
        override = target.instance_methods.include?(method)

        value_writer = case true
        when override
          "self.#{attribute}_without_enums = value"
        when target.instance_methods.include?(:write_attribute) || target.private_instance_methods.include?(:write_attribute)
          "write_attribute :#{attribute}, value"
        else
          # We need a writer to fall back to.
          raise "cannot overwrite enum writer - no existing writer found"
        end

        body.gsub! '%{write_value}', value_writer

        if override
          target.class_eval <<-RUBY, __FILE__, __LINE__+1
            def #{attribute}_with_enums=(value)
              #{body}
            end
            alias_method_chain :#{attribute}=, :enums
          RUBY
        else
          target.class_eval <<-RUBY, __FILE__, __LINE__+1
            def #{attribute}=(value)
              #{body}
            end
          RUBY
        end
      end

    ######
    # Single enum reader & writer

      def self.define_single_reader(target, attribute)
        define_reader target, attribute, <<-RUBY
          case value = %{read_value}
          when EnumX::Value then value
          when nil then nil
          else
            enum = EnumX.find(self.class, :#{attribute.to_s.pluralize})
            enum[value] || value
          end
        RUBY
      end

      def self.define_single_writer(target, attribute)
        define_writer target, attribute, <<-RUBY
          value = case value
          when EnumX::Value then value
          when nil then nil
          else
            enum = EnumX.find(self.class, :#{attribute.to_s.pluralize})
            enum[value] || value
          end
          %{write_value}
        RUBY
      end

    ######
    # Multi enum reader & writer

      def self.define_multi_reader(target, attribute)
        define_reader target, attribute, <<-RUBY
          enum = EnumX.find(self.class, :#{attribute.to_s})
          case value = %{read_value}
          when nil then nil
          when EnumX::ValueList then value
          when Enumerable then EnumX::ValueList.new(enum, value)
          else EnumX::ValueList.new(enum, [value])
          end
        RUBY
      end

      def self.define_multi_writer(target, attribute)
        define_writer target, attribute, <<-RUBY
          enum = EnumX.find(self.class, :#{attribute.to_s})
          value = case value
          when nil then nil
          when EnumX::ValueList then value
          when Enumerable then EnumX::ValueList.new(enum, value)
          else EnumX::ValueList.new(enum, [value])
          end
          %{write_value}
        RUBY
      end

    ######
    # Mnemonics (single & multi)

      def self.define_mnemonics(target, attribute, enum)
        enum.values.each do |value|
          target.class_eval <<-RUBY, __FILE__, __LINE__+1
            def #{value}?
              :#{value} === #{attribute}
            end
          RUBY
        end
      end

    ######
    # Serializer

      class SingleSerializer
        def initialize(enum)
          @enum = enum
        end

        def load(text) @enum[text] end
        def dump(value) value.to_s end
      end

      class FlagsSerializer
        def initialize(enum)
          @enum = enum
        end

        def load(text)
          EnumX::ValueList.new(@enum, text.to_s.split('|').reject(&:blank?))
        end

        def dump(list)
          # This is the case for using the values from changes and the list is allready a string
          list = load(list).values unless list.is_a?(EnumX::ValueList)
          "|#{list.map(&:to_s).join('|')}|"
        end
      end

  end

end