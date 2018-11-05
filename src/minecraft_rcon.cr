require "socket"

module Minecraft::RCON
  VERSION = "0.1.0"

  # A response from the RCON server
  struct Packet
    # Exception to be raised when reading or writing a packet fails
    class Error < Exception
    end

    enum Type
      Response = 0
      Command  = 2
      Login    = 3
    end

    # :nodoc:
    PADDING = Bytes[0, 0]

    # The request ID this packet represents
    getter request_id : Int32

    # The type of packet
    getter type : Type

    # The raw payload in bytes
    getter payload : Bytes

    # Creates a new `Packet` with the given `request_id`, `Type`, and payload.
    # Payload should be `Bytes`, or otherwise respond to `#to_slice : Bytes`.
    def initialize(@request_id : Int32, @type : Type, payload)
      @payload = payload.to_slice
    end

    # Reads a `Packet` from the given IO.
    def self.from_io(io, format)
      remainder_length = io.read_bytes(Int32, format)

      request_id = io.read_bytes(Int32, format)
      type = Type.new(io.read_bytes(Int32, format))

      payload_length = remainder_length - sizeof(Int32) * 2 - PADDING.size
      payload_buffer = Bytes.new(payload_length)
      io.read(payload_buffer)

      padding_bytes = Bytes.new(PADDING.size)
      io.read(padding_bytes)
      raise Error.new("Unexpected padding bytes: #{padding_bytes}") unless padding_bytes == PADDING

      new(request_id, type, payload_buffer)
    end

    # Writes a `Packet` to the given IO.
    def to_io(io, format)
      remainder_size = sizeof(Int32) * 2 + @payload.size + PADDING.size
      total_size = remainder_size + sizeof(Int32)
      buffer = Bytes.new(remainder_size + sizeof(Int32))

      format.encode(remainder_size, buffer[0, 4])
      format.encode(@request_id, buffer[4, 4])
      format.encode(@type.value, buffer[8, 4])
      @payload.copy_to(buffer[12, @payload.size])

      io.write(buffer)
    end
  end

  # A client for running RCON commands on a Minecraft server.
  class Client
    class Error < Exception
    end

    # Connects to the server at `ip` and `port`, and logs in with `password`
    def self.connect(ip, port, password)
      client = new(ip, port)
      client.login(password)
      client
    end

    # Creates a new `Client` bound to the given `ip` on `port`.
    def self.new(ip, port)
      new(TCPSocket.new(ip, port))
    end

    # :nodoc:
    def initialize(@socket : IO)
      @request_id = 0
      @logged_in = false
    end

    # Returns the next request ID.
    private def next_request_id
      @request_id += 1
    end

    # Sends a `Packet` to the socket
    private def send(packet : Packet)
      @socket.write_bytes(packet, IO::ByteFormat::LittleEndian)
    end

    # Receives a `Packet` from the socket
    private def receive
      response = @socket.read_bytes(Packet, IO::ByteFormat::LittleEndian)
      raise Error.new("Authentication failed") if response.request_id == -1
      response
    end

    # Closes the connection
    def close
      @socket.close
    end

    # Logs in to the bound Minecraft server with the given `password`.
    def login(password)
      packet = Packet.new(next_request_id, :login, password)
      send(packet)
      receive
      @logged_in = true
    end

    # Executes the given command on the server.
    # You must be logged in first to use this method.
    def execute(command : String)
      raise Error.new("You must be logged in before executing commands!") unless @logged_in
      packet = Packet.new(next_request_id, :command, command)
      send(packet)
      receive
    end

    # :ditto:
    def execute(command : String, *args)
      string = args.to_a.unshift(command).join(' ')
      execute(string)
    end

    # Revokes operator status from the respective player
    def deop(player : String)
      execute("deop", player)
    end

    # Kicks the respective player
    def kick(player : String, reason : String? = nil)
      execute("kick", player, reason)
    end

    # Makes the respective player an operator
    def mkop(player : String)
      execute("op", player)
    end

    # Teleports one player to the other player
    def teleport(player : String, destination_player : String)
      execute("tp", player, destination_player)
    end

    # Teleports one player to a specific position
    def teleport(player : String, x : Float64, y : Float64, z : Float64)
      execute("tp", x, y, z)
    end

    # Teleports one player to a specific position, with orientation
    def teleport(player : String, x : Float64, y : Float64, z : Float64,
                 pitch : Float64, yaw : Float64)
      execute("tp", x, y, z, pitch, yaw)
    end

    # Sends a message from RCON in first-person perspective
    def me(message : String)
      execute("me", message)
    end

    # Broadcast a message to all players
    def say(message : String)
      execute("say", message)
    end

    # Sends a URL to the specified player
    def send_url(player : String, url : String, text : String? = nil)
      payload = {text: text, clickEvent: {action: "open_url", value: url}}
      tell_raw(player, payload)
    end

    # Sends a message represented by a JSON object
    def tell_raw(player : String, object)
      execute("tellraw", player, object.to_json)
    end

    # Returns the players on the server
    def players
      execute("list")
    end

    # Returns the server seed
    def seed
      execute("seed")
    end

    # Locates the respective structure
    def locate(structure : String)
      execute("locate", structure)
    end

    # Summons the respective entity at the given position
    def summon(entity_name : String, x : Float64, y : Float64, z : Float64)
      execute("summon", x, y, z)
    end
  end
end
