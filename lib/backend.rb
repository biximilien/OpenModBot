require_relative "backend/karma_store"
require_relative "backend/moderation_review_store"
require_relative "backend/server_store"
require_relative "backend/watchlist_store"
require_relative "moderation/stores/in_memory_store"

module Backend
  MODERATION_STORE_METHODS = %i[
    add_server
    remove_server
    servers
    add_user_to_watch_list
    remove_user_from_watch_list
    get_watch_list_users
    get_user_karma
    decrement_user_karma
    increment_user_karma
    set_user_karma
    record_user_karma_event
    get_user_karma_history
    record_moderation_review
    get_moderation_reviews
    find_moderation_review
    clear_moderation_reviews
  ].freeze

  def initialize_backend(store: Moderation::Stores::InMemoryStore.new)
    @moderation_store = store
  end

  attr_writer :moderation_store

  def moderation_store
    @moderation_store ||= Moderation::Stores::InMemoryStore.new
  end

  def redis
    moderation_store.redis if moderation_store.respond_to?(:redis)
  end

  MODERATION_STORE_METHODS.each do |method_name|
    define_method(method_name) do |*args, **kwargs, &block|
      moderation_store.public_send(method_name, *args, **kwargs, &block)
    end
  end
end
