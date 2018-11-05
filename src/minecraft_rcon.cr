require "socket"
require "./packet"
require "./commands"

Minecraft::RCON::VERSION = "0.1.0"

# A client for running RCON commands on a Minecraft server.
class Minecraft::RCON::Client
  include Commands

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
end
