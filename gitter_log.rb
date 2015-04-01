require 'net/http'
require 'json'
require 'date'

SERVER_CONFIG       = 'server'
SECURE_TOKEN_CONFIG = 'token'

def weechat_init
  Weechat.register('gitterlog', 'Erick Pintor <erickpintor@gmail.com>', '1.0', 'MIT', 'Loads the history for all your gitter chats', '', '')
  Weechat.hook_command('gitterlog', 'Loads Gitter history', '', 'No arguments', '', 'on_gitterlog', '')
  Weechat.hook_signal('*,irc_in2_join', 'on_join', '')

  Weechat.config_set_plugin(SERVER_CONFIG, 'gitter') unless Weechat.config_is_set_plugin(SERVER_CONFIG)
  Weechat.config_set_plugin(SECURE_TOKEN_CONFIG, '') unless Weechat.config_is_set_plugin(SECURE_TOKEN_CONFIG)

  Weechat::WEECHAT_RC_OK
end

def on_gitterlog(*)
  fetch_logs
end

def on_join(_, signal, data)
  joined_server, _ = signal.split(',')
  return Weechat::WEECHAT_RC_OK if joined_server != Weechat.config_get_plugin(SERVER_CONFIG)

  fetch_logs data.sub(/.*JOIN (.*)$/, '\1')
end

def fetch_logs(filter_channel=nil)
  server = Weechat.config_get_plugin(SERVER_CONFIG)
  secure_token = Weechat.config_get_plugin(SECURE_TOKEN_CONFIG)

  if server.empty? or secure_token.empty?
    Weechat.print '', "Missing #{SERVER_CONFIG} or #{SECURE_TOKEN_CONFIG} properties. Check gitterlog configurations."
    return Weechat::WEECHAT_RC_ERROR
  end

  GitterLog.new(server, filter_channel, secure_token).fetch
  Weechat::WEECHAT_RC_OK
end

class GitterLog

  def initialize(server, filter_channel, secure_token)
    @server = server
    @filter_channel = filter_channel
    @fetcher = UrlFetcher.new(secure_token)
  end

  def fetch
    @fetcher.fetch_url(Room.rooms_url) { |rooms_data| fetch_rooms rooms_data }
  end

  private

  def fetch_rooms(rooms_data)
    threads = rooms_data.map do |room_data|
      Thread.new do
        fetch_logs_for_room Room.parse(@server, room_data)
      end
    end

    threads.each(&:join)
  end

  def fetch_logs_for_room(room)
    return unless room.should_fetch? @filter_channel

    @fetcher.fetch_url(room.messages_url) do |messages_data|
      print room, Message.parse(messages_data)
    end
  end

  def print(room, messages)
    messages_to_show = messages.select(&:show?)
    return if messages_to_show.empty? or room.buffer.nil?

    messages_to_show.each do |message|
      Weechat.print room.buffer, message.text
    end
  end
end

class UrlFetcher

  def initialize(secure_token)
    @secure_token = secure_token
  end

  def fetch_url(address)
    uri = URI.parse(address)
    response = perform_request(uri, http_get(uri))

    yield JSON.parse(response.body) if response.is_a? Net::HTTPSuccess
  end

  private

  def perform_request(uri, http_request)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request http_request
    end
  end

  def http_get(uri)
    Net::HTTP::Get.new(uri).tap do |request|
      request['Accept'] = 'application/json'
      request['Authorization'] = "Bearer #{@secure_token}"
    end
  end
end

module IRCBuffer
  private

  def find_or_join_buffer(server, channel, join_command)
    server_buffer, channel_buffer = irc_buffers(server, channel)
    return channel_buffer unless server_buffer == channel_buffer

    Weechat.command(server_buffer, join_command)
    nil
  end

  def irc_buffers(server, channel)
    [irc_buffer(server), irc_buffer("#{server},#{channel}")]
  end

  def irc_buffer(buffer_name)
    Weechat.info_get('irc_buffer', buffer_name)
  end
end

class Room
  include IRCBuffer

  def self.parse(server, room_data)
    if room_data['uri'].nil?
      self.new server, room_data['id'], PrivateChat.new(room_data['user']['username'])
    else
      self.new server, room_data['id'], PublicChat.new(room_data['uri'])
    end
  end

  def self.rooms_url
    'https://api.gitter.im/v1/rooms'
  end

  def initialize(server, id, chat)
    @server = server
    @id = id
    @chat = chat
  end

  def should_fetch?(filter_channel)
    filter_channel.nil? or filter_channel == @chat.name
  end

  def messages_url
    'https://api.gitter.im/v1/rooms/%s/chatMessages' % @id
  end

  def buffer
    @buffer ||= find_or_join_buffer(@server, @chat.name, @chat.join_command)
  end
end

class Message
  def self.parse(message_data)
    message_data.map do |message|
      self.new message['text'],
               message['sent'],
               message['fromUser']['username']
    end
  end

  def initialize(text, sent_at, username)
    @text = text
    @username = username
    @sent_at = DateTime.parse(sent_at)
  end

  def show?
    @sent_at >= DateTime.now - 1
  end

  def text
    "#{@username}\t#{@sent_at.strftime('[%y-%m-%d %H:%M:%S]')} #{@text}"
  end
end

class Chat
  attr_reader :name

  def initialize(name)
    @name = name
  end
end

class PrivateChat < Chat
  def join_command
    "/Q #{name}"
  end
end

class PublicChat < Chat
  def name
    "##{super}"
  end

  def join_command
    "/join #{name}"
  end
end
