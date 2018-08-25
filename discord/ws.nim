when not defined(ssl):
  {.fatal: "SSL not loaded for Discord. Do `nim c -d:ssl`".}

import
  websocket, asyncdispatch, asyncnet, http, json, uri, net, common, tables

when defined(discordCompress): from zip/zlib import uncompress

let gateway* = get(api / "gateway")["url"].getStr().parseUri().hostname
client.ws = waitFor newAsyncWebsocketClient("wss://" & gateway & ":443/?encoding=json&v=6")

client.lastSeq = 0

proc send*(data: JsonNode) {.async.} =
  await client.ws.sendText($data, masked = true)

template send(op: int, data: untyped): auto =
  send(%*{
    "op": op,
    "d": data
  })

proc identify* {.async.} =
  asyncCheck send(op = 2, {
    "token": token,
    "compress": defined(discordCompress),
    "large_threshold": 250,
    "properties": {
      "$os": hostOS,
      "$browser": "Nim",
      "$device": "Nim"
    }
  })

proc heartbeat*(interval: int) {.async.} =
  while not client.ws.sock.isClosed:
    asyncCheck send(op = 1, client.lastSeq)
    await sleepAsync(interval)

proc process*(data: JsonNode) =
  let op = data["op"].getInt()
  case op
  of 0:
    client.lastSeq = data["s"].getInt()
    let
      d = data["d"]
      t = data["t"].getStr()
    client.listeners.withValue(t, procs) do:
      for p in procs[]:
        p(d)
  of 10:
    asyncCheck heartbeat(data["d"]["heartbeat_interval"].getInt)
    asyncCheck identify()
  else: discard

proc read* {.async.} =
  while not client.ws.sock.isClosed:
    let (opcode, data) = await client.ws.readData()
    case opcode
    of Opcode.Text:
      let json = parseJson(data)
      process json
    of Opcode.Binary:
      when defined(discordCompress):
        let text = uncompress(data)
        if text.isNil:
          echo "Decompression failed, ignoring"
        else:
          process parseJson(text)
    else: continue