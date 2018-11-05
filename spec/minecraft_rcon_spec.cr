require "./spec_helper"

private def with_server
  TCPServer.open("localhost", 0) do |server|
    client = Minecraft::RCON::Client.new("localhost", server.local_address.port)
    socket = server.accept
    yield client, socket
  end
end

describe Minecraft::RCON do
  describe Minecraft::RCON::Packet do
    it "can be read from an IO" do
      payload = Bytes[
        14, 0, 0, 0, # remainder length
        1, 0, 0, 0,  # request ID 1
        2, 0, 0, 0,  # type 2 (command)
        3, 4, 5, 6,  # payload
        0, 0]        # padding

      io = IO::Memory.new(payload)
      packet = io.read_bytes(Minecraft::RCON::Packet, IO::ByteFormat::LittleEndian)
      packet.request_id.should eq 1
      packet.type.should eq Minecraft::RCON::Packet::Type::Command
      packet.payload.should eq Bytes[3, 4, 5, 6]
    end

    it "can be written to an IO" do
      packet = Minecraft::RCON::Packet.new(1, :login, "pass")
      io = IO::Memory.new
      io.write_bytes(packet, IO::ByteFormat::LittleEndian)
      bytes = io.buffer.to_slice(io.size)
      bytes.should eq Bytes[
        14, 0, 0, 0,
        1, 0, 0, 0,
        3, 0, 0, 0,
        112, 97, 115, 115,
        0, 0]
    end
  end

  describe Minecraft::RCON::Client do
    it "logs in and sends commands" do
      with_server do |client, server|
        spawn do
          client.login("password")
          client.execute("command")
        end

        request = server.read_bytes(Minecraft::RCON::Packet, IO::ByteFormat::LittleEndian)
        request.should eq Minecraft::RCON::Packet.new(1, :login, "password".to_slice)
        server.write_bytes(Minecraft::RCON::Packet.new(1, :response, Bytes.empty))

        request = server.read_bytes(Minecraft::RCON::Packet, IO::ByteFormat::LittleEndian)
        request.should eq Minecraft::RCON::Packet.new(2, :command, "command".to_slice)
        server.write_bytes(Minecraft::RCON::Packet.new(2, :response, Bytes.empty))
      end
    end

    it "buffers multiple frames" do
      with_server do |client, server|
        spawn do
          request = server.read_bytes(Minecraft::RCON::Packet, IO::ByteFormat::LittleEndian)
          server.write_bytes(Minecraft::RCON::Packet.new(1, :response, Bytes.empty))

          request = server.read_bytes(Minecraft::RCON::Packet, IO::ByteFormat::LittleEndian)
          request.should eq Minecraft::RCON::Packet.new(2, :command, "list")
          server.write_bytes(Minecraft::RCON::Packet.new(2, :response, "first payload"))
          server.write_bytes(Minecraft::RCON::Packet.new(2, :response, "second payload"))
        end
        client.login("sethhax4life")
        client.execute("list").to_s.should eq "first payloadsecond payload"
      end
    end

    it "raises when authentication fails" do
      with_server do |client, server|
        spawn do
          request = server.read_bytes(Minecraft::RCON::Packet, IO::ByteFormat::LittleEndian)
          request.should eq Minecraft::RCON::Packet.new(1, :login, "sethhax4life".to_slice)
          server.write_bytes(Minecraft::RCON::Packet.new(-1, :response, Bytes.empty))
        end

        expect_raises(Minecraft::RCON::Client::Error, "Authentication failed") do
          client.login("sethhax4life")
        end
      end
    end

    it "raises when trying to send commands when not logged in" do
      with_server do |client, server|
        expect_raises(Minecraft::RCON::Client::Error, "You must be logged in before executing commands!") do
          client.execute("spawn butterdogs")
        end
      end
    end
  end
end
