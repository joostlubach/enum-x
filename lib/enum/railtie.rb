require File.expand_path('..', __FILE__)

class Enum
  class Railtie < Rails::Railtie

    config.enum = ActiveSupport::OrderedOptions.new
    config.enum.load_paths = []

    initializer 'enum.set_load_paths', :before => :finisher_hook do |app|
      Enum.load_paths = app.config.enum.load_paths
    end

  end
end