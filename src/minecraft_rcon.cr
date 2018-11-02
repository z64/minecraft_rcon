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

    # Sends a `Packet` to the socket, and returns the response.
    private def send(packet : Packet)
      @socket.write_bytes(packet, IO::ByteFormat::LittleEndian)
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
      @logged_in = true
    end

    # Executes the given command on the server.
    # You must be logged in first to use this method.
    def execute(command : String)
      raise Error.new("You must be logged in before executing commands!") unless @logged_in
      packet = Packet.new(next_request_id, :command, command)
      send(packet)
    end
  end
end
