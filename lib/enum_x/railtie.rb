require File.expand_path('..', __FILE__)

class EnumX
  class Railtie < Rails::Railtie

    config.enum_x = ActiveSupport::OrderedOptions.new
    config.enum_x.load_paths = []

    initializer 'enum.set_load_paths', :before => :finisher_hook do |app|
      EnumX.load_paths = app.config.enum_x.load_paths
    end

  end
end