import uri, tables, json

type Listener* = proc(node: JsonNode)

const configFile* = when defined(discordconfig): discordConfigFile else: "bot.json"

when defined(discordstaticconfig):
  const config* = parseFile(configFile)
  const token* = "Bot " & config["token"].getStr()
elif defined(discordclitoken):
  import os

  if paramCount() == 0:
    quit "Discord token needed in command line arguments."

  let token* = "Bot " & paramStr(1)
else:
  let config* = parseFile(configFile)
  let token* = "Bot " & config["token"].getStr()

const
  discordUserAgent* = "NimBot (1.0 https://github.com/hlaaftana)"
  api* = "https://discordapp.com/api/v6/".parseUri()
  messageEvent* = "MESSAGE_CREATE"

var listeners* = initTable[string, seq[Listener]]()

proc addListener*[T: proc](e: string, a: T) =
  let a =
    when T is Listener:
      a
    else:
      Listener(a)
  listeners.withValue(e, x) do:
    x[].add(a)
  do:
    listeners[e] = @[a]