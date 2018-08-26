when false and not defined(ssl):
  {.fatal: "SSL not loaded for Discord. Do `nim c -d:ssl`".}

import
  websocket, asyncdispatch, asyncnet, http, uri, net, common, tables

when defined(etf):
  import etf
else:
  import json

when defined(discordCompress):
  from zip/zlib import uncompress

proc send*(ws: AsyncWebSocket, data: JsonNode) {.async.} =
  await ws.sendText($data, masked = true)

template send(ws: AsyncWebSocket, op: int, data: untyped): auto =
  ws.send(%*{
    "op": op,
    "d": data
  })

proc identify*(ws: AsyncWebSocket, token: string) {.async.} =
  when defined(etf):
    asyncCheck ws.sendText(toBytes(Term(tag: ttMap, map: @[
      (Term(tag: ttAtomUtf8, atom: "op".Atom), Term(tag: ttUint8, u8: 2)),
      (Term(tag: ttAtomUtf8, atom: "d".Atom), Term(tag: ttMap, map: @[
        (Term(tag: ttAtomUtf8, atom: "token".Atom), Term(tag: ttString, str: token)),
        (Term(tag: ttAtomUtf8, atom: "compress".Atom), Term(tag: ttUint8, u8: defined(discordCompress).byte)),
        (Term(tag: ttAtomUtf8, atom: "large_threshold".Atom), Term(tag: ttUint8, u8: 250)),
        (Term(tag: ttAtomUtf8, atom: "propertis".Atom), Term(tag: ttMap, map: @[
          (Term(tag: ttAtomUtf8, atom: "$os".Atom), Term(tag: ttString, str: hostOS)),
          (Term(tag: ttAtomUtf8, atom: "$browser".Atom), Term(tag: ttString, str: "Nim")),
          (Term(tag: ttAtomUtf8, atom: "$device".Atom), Term(tag: ttString, str: "Nim"))]))]))])), masked = true)
  else:
    asyncCheck ws.send(op = 2, {
      "token": token,
      "compress": defined(discordCompress),
      "large_threshold": 250,
      "properties": {
        "$os": hostOS,
        "$browser": "Nim",
        "$device": "Nim"
      }
    })

proc heartbeat*(ws: AsyncWebSocket, lastSeq: int, interval: int) {.async.} =
  while not ws.sock.isClosed:
    when defined(etf):
      asyncCheck ws.sendText(toBytes(Term(tag: ttMap, map: @[
        (Term(tag: ttAtomUtf8, atom: "op".Atom), Term(tag: ttUint8, u8: 1)),
        (Term(tag: ttAtomUtf8, atom: "d".Atom), Term(tag: ttInt32, i32: client.lastSeq.int32))])))
    else:
      asyncCheck ws.send(op = 1, lastSeq)
    await sleepAsync(interval)

proc process*(dispatcher: Dispatcher, ws: AsyncWebSocket, token: string, lastSeq: ref int, data: JsonNode) =
  let op = data["op"].getInt()
  case op
  of 0:
    lastSeq[] = data["s"].getInt()
    let
      d = data["d"]
      t = data["t"].getStr()
    if t == "READY": echo "readied"
    dispatcher.dispatch(t, d)
  of 10:
    echo "heartbeating & identifying"
    asyncCheck heartbeat(ws, lastSeq[], data["d"]["heartbeat_interval"].getInt)
    asyncCheck identify(ws, token)
  else: discard

proc read*(dispatcher: Dispatcher, ws: AsyncWebSocket, token: string, lastSeq: ref int) {.async.} =
  while not ws.sock.isClosed:
    let (opcode, data) = await ws.readData()
    case opcode
    of Opcode.Text:
      when defined(etf):
        if data[0] == 131.char:
          let etf = parseEtf(data)
          echo data
          echo "data: ", cast[seq[byte]](data)
          echo (if etf.isNil: "nil" else: $(etf[]))
        else:
          let json = parseJson(data)
          process dispatcher, ws, token, lastSeq, json
      else:
        let json = parseJson(data)
        process dispatcher, ws, token, lastSeq, json
    of Opcode.Binary:
      when defined(discordCompress):
        let text = uncompress(data)
        if text.isNil:
          echo "Decompression failed, ignoring"
        else:
          process dispatcher, ws, token, lastSeq, parseJson(text)
    else: continue