import uri, os, tables, json

type Listener* = proc(node: JsonNode)

const
  discordUserAgent* = "NimBot (1.0 https://github.com/hlaaftana)"
  api* = "https://discordapp.com/api/v6/".parseUri()
  messageEvent* = "MESSAGE_CREATE"

if paramCount() == 0:
  raise newException(Exception, "Please supply a token argument")

let token* = "Bot " & paramStr(1).string

var listeners* = initTable[string, seq[Listener]]()

proc addListener*(e: string, a: Listener) =
  listeners.withValue(e, x) do:
    x[].add(a)
  do:
    listeners[e] = @[a]