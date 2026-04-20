require "plugin_registry"

class CustomPlugin < ModerationGPT::Plugin
  def commands
    [:custom_command]
  end
end

ModerationGPT::PluginRegistry.register("custom") { CustomPlugin.new }
