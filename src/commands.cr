# Mixin providing a high-level binding to RCON commands
module Minecraft::RCON::Commands
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
