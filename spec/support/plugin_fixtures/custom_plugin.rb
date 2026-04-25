require "plugin_registry"

class CustomPluginCommand
  def matches?(event)
    event.message.content == "!moderation custom"
  end

  def handle(event)
    event.respond("Handled custom plugin command")
  end

  def help_lines
    ["!moderation custom"]
  end
end

class CustomPlugin < ModerationGPT::Plugin
  def commands
    [CustomPluginCommand.new]
  end
end

ModerationGPT::PluginRegistry.register("custom") { CustomPlugin.new }
