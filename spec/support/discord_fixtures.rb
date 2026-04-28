module DiscordFixtures
  def moderation_event(content:, server_id: 123, channel_id: 789, user_id: 42, administrator: true)
    user = instance_double("User", id: user_id, name: "User")
    message = instance_double("Message", id: 111, content: content, delete: true)
    member = instance_double("Member", id: user_id, permission?: administrator)
    server = instance_double("Server", id: server_id, members: [member])
    channel = instance_double("Channel", id: channel_id)

    instance_double("Event", message: message, server: server, channel: channel, user: user, respond: true)
  end
end

RSpec.configure do |config|
  config.include DiscordFixtures
end
