# This file contains extensions to Symbol and String so that enum values can be
# used in case statementes

# Extend Symbol and String's == and === method to match equal enum values as well
Symbol.class_eval do
  def triple_equals_with_enums(arg)
    if arg.is_a?(EnumX::Value)
      triple_equals_without_enums arg.symbol
    elsif arg.is_a?(EnumX::ValueList)
      arg.include?(self)
    else
      triple_equals_without_enums arg
    end
  end
  def double_equals_with_enums(arg)
    if arg.is_a?(EnumX::Value)
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
    if arg.is_a?(EnumX::Value)
      triple_equals_without_enums arg.value
    elsif arg.is_a?(EnumX::ValueList)
      arg.include?(self)
    else
      triple_equals_without_enums arg
    end
  end
  def double_equals_with_enums(arg)
    if arg.is_a?(EnumX::Value)
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