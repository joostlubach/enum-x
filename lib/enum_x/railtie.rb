require File.expand_path('..', __FILE__)

class EnumX
  class Railtie < Rails::Railtie

    config.enum_x = ActiveSupport::OrderedOptions.new
    config.enum_x.load_paths = []

    initializer 'enum.set_load_paths', :before => :finisher_hook do |app|
      EnumX.load_paths.concat app.config.enum_x.load_paths
    end

    initializer 'enum.add_to_activerecord', :before => :finisher_hook do |app|
      ActiveRecord::Base.send :include, EnumX::DSL if defined?(ActiveRecord)
    end

  end
end