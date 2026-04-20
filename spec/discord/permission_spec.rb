require "discord"
require "discord/permission"

describe Discord::Permission do
  describe "#MODERATION_BOT" do
    it "includes the permissions needed to moderate text channels" do
      expected = Discord::Permission::VIEW_CHANNEL |
                 Discord::Permission::SEND_MESSAGES |
                 Discord::Permission::MANAGE_MESSAGES |
                 Discord::Permission::READ_MESSAGE_HISTORY |
                 Discord::Permission::MODERATE_MEMBERS

      expect(Discord::Permission::MODERATION_BOT).to eq(expected)
    end

    it "does not include administrator permissions" do
      administrator = 1 << 3

      expect(Discord::Permission::MODERATION_BOT & administrator).to eq(0)
    end
  end
end
