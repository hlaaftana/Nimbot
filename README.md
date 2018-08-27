# pkpsgpsg
Discord bot in Nim 0.18.0. Stands for Pun K Psrps So Gory Pthat Someone Goe'daway. Pack Passage Passage. Pessage Pessage.

This has no OOP or proc overhead unless you want to have them. The event dispatcher can be user defined as long as it has
a dispatch(dispatcher, eventName, json) method. In fact the only overhead is the fact that JSON gets parsed.

2 samples, 1 of which is baseline, the other uses the command helper:

```nim
import discord/[discord, messages], asyncdispatch

type Client = ref object # this is going to be our Dispatcher object
  instance: DiscordInstance # stores HTTP and WS client

proc dispatch(client: Client, event: string, node: JsonNode) =
  case event
  of "MESSAGE_CREATE":  
    let message = MessageEvent(node) # this type is defined in messages
    let content = message.content

    template reply(content: string, tts = false) = # convenience template
      asyncCheck client.instance.http.reply(message, content, tts)

    if content == "TEXT THAT THE BOT HAS TO REPLY TO":
      reply "OK i replied, Bro"
  else:
    discard

var client: Client
new(client)
init(client, "token", client.instance) # fills instance variable with data if not already initialized
runForever()
```

```nim
import strutils, discord/[discord, commands, messages]

var
  dispatcher: ListenerDispatcher # one of the predefined dispatcher types, has proc AND table overhead
  handler = CommandHandler(prefixes: @["!"], commands: @[]) # has proc overhead for each command
  instance: DiscordInstance # this has to be a var because the library is going to inject data into it later

dispatcher.init() # initializes listener table

# hook the command handler to the dispatcher
dispatcher.addListener("MESSAGE") do (node: JsonNode):
  handler.handleCommand(MessageEvent(node))

template cmd(alias: string, body) =
  proc cmdProc(content, args: string, message: MessageEvent) {.gensym.} =
    let # nim limitation
      content {.inject, used.} = content
      args {.inject, used.} = args
      message {.inject, used.} = args
    body
  handler.commands.add(Command(prefix: alias, callback: cmdProc))

template respond(cont: string, tts = false): untyped =
  instance.http.reply(message, filterText(cont), tts)

cmd "say":
  asyncCheck respond(args) # asyncCheck is how you discard async calls

init(dispatcher, "token", instance)
```

Installation:

```
git clone https://github.com/hlaaftana/pkpsgpsg
cd pkpsgpsg
nimble install websocket
```

For compression if you want, you can get [zip](https://github.com/nim-lang/zip) and zlib1.dll and `-d:discordcompress` and hope for the best cuz it probably wont work right now.

Feel free to steal, just make sure to remember who you stole from.