import uri, tables, json, httpclient, websocket

type Listener* = proc(node: JsonNode)

type DiscordClient* = ref object
  token*: string
  http*: AsyncHttpClient
  ws*: AsyncWebSocket
  listeners*: Table[string, seq[Listener]]
  sessionId*: string
  lastSeq*: int

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

let client* = new DiscordClient
client.listeners = initTable[string, seq[Listener]]()
client.token = token

proc addListener*[T: proc](e: string, a: T) =
  let a =
    when T is Listener:
      a
    else:
      Listener(a)
  client.listeners.withValue(e, x) do:
    x[].add(a)
  do:
    client.listeners[e] = @[a]

client.http = newAsyncHttpClient(discordUserAgent)
client.http.headers = newHttpHeaders({"Authorization": token})