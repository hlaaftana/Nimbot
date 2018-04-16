import json, http, uri, common, strutils, macros

type
  MessageEvent* = distinct JsonNode
  MessageListener* = proc(obj: MessageEvent) 

  CommandProc*[T] = proc(cachedContent: string, args: string, obj: MessageEvent): T

  Command* = object
    prefix*: string
    callback*: CommandProc[void]

  CommandHandler* = object
    commands*: seq[Command]
    allowMultiple*: bool
    prefix*: string
    predicate*: CommandProc[bool]
    filter*: proc(text: string): string
    noMatch*: CommandProc[void]

var handler*: CommandHandler
handler.commands = @[]

proc channelId*(msg: MessageEvent): string {.inline.} =
  JsonNode(msg)["channel_id"].getStr()

proc content*(msg: MessageEvent): string {.inline.} =
  JsonNode(msg)["content"].getStr()

proc sendMessage*(channelId: string, content: string, tts: bool = false): auto =
  var payload = newJObject()
  payload["content"] = %content
  if tts: payload["tts"] = %true
  post(api / "channels" / channelId / "messages", payload)

template reply*(msg: MessageEvent, content: string, tts: bool = false): auto =
  sendMessage(msg.channelId, content, tts)

# template because addListener needs to be top level to be safe
proc commandListener*(hndl: CommandHandler): Listener =
  result = proc(obj: JsonNode) =
    let msg = MessageEvent(obj)
    var matched: bool
    let cont = msg.content
    var curr = cont
    let hf = hndl.predicate
    if not hf.isNil and not hf(cont, curr, msg):
      return
    let hp = hndl.prefix
    if not hp.isNil:
      if not curr.startsWith(hp):
        return
      else:
        curr.removePrefix(hp)
    for cmd in hndl.commands:
      let p = cmd.prefix
      if curr.startsWith(p):
        var args: string
        if hndl.allowMultiple:
          args = curr
        else:
          args.shallowCopy(curr)
        args.removePrefix(p)
        let ended = args.len == 0
        if ended or args[0] in Whitespace:
          matched = true
          if not ended:
            args = args.strip(trailing = false)
          cmd.callback(cont, args, MessageEvent(obj))
          if not hndl.allowMultiple:
            return
    if not matched and not hndl.noMatch.isNil:
      hndl.noMatch(cont, curr, MessageEvent(obj))

template addCommands*: untyped =
  addListener(messageEvent, commandListener(handler))

proc filterText*(hndl: CommandHandler, text: string): string {.inline.} =
  if hndl.filter.isNil:
    result = text
  else:
    result = (hndl.filter)(text)

template prefix*(s: string): untyped =
  handler.prefix = s

template filter*(body: untyped): untyped =
  block:
    proc filterProc(text: string): string =
      let text {.inject.} = text
      body
    handler.filter = filterProc

template filter*(name, body: untyped): untyped =
  block:
    proc filterProc(text: string): string =
      let `name` {.inject.} = text
      body
    handler.filter = filterProc

template predicate*(body: untyped): untyped =
  block:
    proc predProc(content, args: string, message: MessageEvent): bool =
      template respond(cont: string, tts: bool = false): untyped {.inject.} =
        reply(message, filterText(handler, cont), tts)
      let
        content {.inject, used.} = content
        args {.inject, used.} = args
        message {.inject, used.} = message
      body
    handler.predicate = predProc

template command*(alias: string, body: untyped): untyped =
  block:
    proc cmdProc(content, args: string, message: MessageEvent) =
      template respond(cont: string, tts: bool = false): untyped {.inject.} =
        reply(message, filterText(handler, cont), tts)
      let
        content {.inject, used.} = content
        args {.inject, used.} = args
        message {.inject, used.} = message
      body
    let cmd = Command(prefix: alias, callback: cmdProc)
    if handler.commands.isNil:
      handler.commands = @[cmd]
    else:
      handler.commands.add(cmd)