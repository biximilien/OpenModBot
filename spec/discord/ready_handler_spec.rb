require "discord"
require "discord/ready_handler"

describe Discord::ReadyHandler do
  subject(:handler) { described_class.new(bot, store) }

  let(:store) { instance_double("Store", add_server: true) }
  let(:text_channel) { instance_double("Channel", name: "general", type: 0, id: 111) }
  let(:voice_channel) { instance_double("Channel", name: "voice", type: 2, id: 222) }
  let(:server) { instance_double("Server", name: "Test Server", channels: [text_channel, voice_channel]) }
  let(:bot) { instance_double("Bot", online: true, servers: { 123 => server }) }
  let(:event) { instance_double("ReadyEvent") }

  it "marks the bot online" do
    handler.handle(event)

    expect(bot).to have_received(:online)
  end

  it "registers connected servers" do
    handler.handle(event)

    expect(store).to have_received(:add_server).with(123)
  end

  it "handles empty server lists" do
    empty_bot = instance_double("Bot", online: true, servers: {})

    described_class.new(empty_bot, store).handle(event)

    expect(empty_bot).to have_received(:online)
    expect(store).not_to have_received(:add_server)
  end
end
