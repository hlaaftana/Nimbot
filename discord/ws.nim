when not defined(ssl):
  {.fatal: "SSL not loaded for Discord. Do `nim c -d:ssl`".}

import
  websocket, asyncdispatch, asyncnet, http, json, uri, net, common, tables

when defined(discordCompress): from zip/zlib import uncompress

let gateway* = get(api / "gateway")["url"].getStr().parseUri().hostname
let wsClient* = waitFor newAsyncWebsocket(
  "wss://" & gateway & ":443/?encoding=json&v=6",
  ctx = newContext(verifyMode = CVerifyNone))

var lastSeq* = 0
var sessionId*: string

proc send*(data: JsonNode) {.async.} =
  await wsClient.sock.sendText($data, true)

template sendOp(op: int, data: untyped): auto =
  send(%*{
    "op": op,
    "d": data
  })

proc identify* {.async.} =
  asyncCheck sendOp(2, {
    "token": token,
    "compress": when defined(discordCompress): true else: false,
    "large_threshold": 250,
    "properties": {
      "$os": hostOS,
      "$browser": "Nim",
      "$device": "Nim"
    }
  })

proc heartbeat*(interval: int) {.async.} =
  while not wsClient.sock.isClosed:
    asyncCheck sendOp(1, lastSeq)
    await sleepAsync(interval)

proc process*(data: JsonNode) =
  let op = data["op"].getInt()
  case op
  of 0:
    lastSeq = data["s"].getInt()
    let
      d = data["d"]
      t = data["t"].getStr()
    listeners.withValue(t, procs) do:
      for p in procs[]:
        p(d)
  of 10:
    asyncCheck heartbeat(data["d"]["heartbeat_interval"].getInt)
    asyncCheck identify()
  else: discard

proc read* {.async.} =
  while not wsClient.sock.isClosed:
    let d = await wsClient.sock.readData(true)
    case d.opcode
    of Opcode.Text:
      let text = d.data
      let json = parseJson(text)
      process json
    of Opcode.Binary:
      when defined(discordCompress):
        let text = uncompress(d.data)
        if text.isNil:
          echo "Decompression failed, ignoring"
        else:
          process parseJson(text)
    else: continue