# minecraft_rcon

A simple client for sending RCON commands to a Minecraft server.

- [RCON documentation](https://wiki.vg/RCON)

## Installation

Add this to your application's `shard.yml`:

```yaml
dependencies:
  minecraft_rcon:
    github: z64/minecraft_rcon
```

## Usage

```crystal
require "minecraft_rcon"

client = Minecraft::RCON::Client.connect("ip address", 25565, "password")
client.execute("kick PixeLInc")
client.execute("say my work here is done")
client.close
```

## Contributors

- [z64](https://github.com/z64) Zac Nowicki - creator, maintainer
