import uri, os, tables, json

type Listener* = proc(node: JsonNode)

const
  discordUserAgent* = "NimBot (1.0 https://github.com/hlaaftana)"
  api* = "https://discordapp.com/api/v6/".parseUri()
  messageEvent* = "MESSAGE_CREATE"

let config* = parseFile("bot.json")
let token* = "Bot " & config["token"].getStr

var listeners* = initTable[string, seq[Listener]]()

proc addListener*[T: proc](e: string, a: T) =
  let a = when T is Listener: a else: Listener(a)
  listeners.withValue(e, x) do:
    x[].add(a)
  do:
    listeners[e] = @[a]