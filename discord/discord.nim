import websocket, httpclient, common, http, ws, asyncdispatch, json, tables

type DiscordInstance* = object
  ws*: AsyncWebSocket
  http*: AsyncHttpClient
  gateway*: string
  lastSeq*: ref int

proc init*(dispatcher: Dispatcher, token: string, instance: var DiscordInstance) {.gcsafe.} =
  instance.http = newAsyncHttpClient(discordUserAgent)
  instance.http.headers = newHttpHeaders({"Authorization": "Bot " & token})
  instance.gateway = instance.http.get(api / "gateway")["url"].getStr().parseUri().hostname
  instance.ws = waitFor newAsyncWebsocketClient("wss://" & instance.gateway & ":443/?encoding=" & (when defined(etf): "etf" else: "json") & "&v=6")
  instance.lastSeq.new()
  asyncCheck read(dispatcher, instance.ws, token, instance.lastSeq)

type
  Listener* = proc(node: JsonNode): void
  ListenerDispatcher* = object
    listeners: Table[string, seq[Listener]]

proc init*(dispatcher: var ListenerDispatcher) =
  dispatcher.listeners = initTable[string, seq[Listener]](4)

proc addListener*(dispatcher: var ListenerDispatcher, event: string, listener: Listener) =
  dispatcher.listeners.mgetOrPut(event, @[]).add(listener)

proc dispatch*(dispatcher: ListenerDispatcher, event: string, node: JsonNode) =
  if dispatcher.listeners.hasKey(event):
    for listener in dispatcher.listeners[event]:
      listener(node)