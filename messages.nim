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
proc commandListener*(handler: CommandHandler): Listener =
  result = proc(obj: JsonNode) =
    let msg = MessageEvent(obj)
    var matched: bool
    let cont = msg.content
    var curr = cont
    let hf = handler.predicate
    if not hf.isNil and not hf(cont, curr, msg):
      return
    let hp = handler.prefix
    if not hp.isNil:
      if not curr.startsWith(hp):
        return
      else:
        curr.removePrefix(hp)
    for cmd in handler.commands:
      let p = cmd.prefix
      if curr.startsWith(p):
        var args: string
        if handler.allowMultiple:
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
          if not handler.allowMultiple:
            return
    if not matched and not handler.noMatch.isNil:
      handler.noMatch(cont, curr, MessageEvent(obj))

proc filter*(handler: CommandHandler, text: string): string {.inline.} =
  if handler.filter.isNil:
    result = text
  else:
    result = (handler.filter)(text)

# i very recently started writing macros, i dont know how to make this prettier
# i tried writing it as a template but i ran into problems, template snippet below
macro commands*(fullBody: untyped): untyped =
  result = newStmtList()
  let handler = ident"handler"
  result.add(quote do:
    var `handler` = CommandHandler(commands: @[]))
  for st in fullBody:
    if st.kind in CallNodes:
      case $st[0]
      of "on":
        let prefix = st[1]
        let body = st[2]
        # if anyone knows how to do this identifier embedding better than i did here please tell me
        # or dont and fix it in your clone that youre not gonna mention me in like you were already gonna do
        let
          cmd = ident"cmd"
          content = ident"content"
          args = ident"args"
          message = ident"message"
        result.add(quote do:
          block:
            var `cmd` = Command(prefix: `prefix`)
            proc cb(`content`, `args`: string, `message`: MessageEvent) =
              template respond(cont: string, tts: bool = false): untyped =
                reply(`message`, filter(`handler`, cont), tts)
              `body`
            `cmd`.callback = CommandProc[void](cb)
            `handler`.commands.add(`cmd`))
      of "prefix":
        let prefix = st[1]
        result.add(quote do:
          `handler`.prefix = `prefix`)
      of "predicate":
        let body = st[1]
        let
          content = ident"content"
          args = ident"args"
          message = ident"message"
        result.add(quote do:
          block:
            proc cb(`content`, `args`: string, `message`: MessageEvent): bool =
              template respond(cont: string, tts: bool = false) =
                reply(message, filter(`handler`, cont), tts)
              `body`
            `handler`.predicate = cb)
      of "filter":
        let body = st[1]
        let
          text = ident"text"
        result.add(quote do:
          block:
            proc cb(`text`: string): string =
              `body`
            `handler`.filter = cb)
      else: result.add(st)
    else: result.add(st)
  result.add(quote do: addListener(messageEvent, commandListener(`handler`)))

when false:
  # it could be so good!!!! but i cant get it to work
  template commands*(fullBody: untyped): untyped {.dirty.} =
    var handler = CommandHandler(commands: @[])

    # says reply has to be discarded even if you wrap respond with asyncCheck
    template command(p, body: untyped): untyped {.dirty.} =
      block:
        var cmd = Command(prefix: p)
        proc cb(content, args: string, message: MessageEvent) =
          template respond(cont: string, tts: bool = false) =
            reply(message, filter(handler, cont), tts)
          body
        cmd.callback = CommandProc[void](cb)
        handler.commands.add(cmd)

    template prefix(p: untyped): untyped =
      handler.prefix = p

    template predicate(body: untyped): untyped {.dirty.} =
      block:
        proc cb(content, args: string, message: MessageEvent): bool =
          template respond(cont: string, tts: bool = false) =
            reply(message, filter(handler, cont), tts)
          body
        handler.predicate = CommandProc[bool](cb)

    # gives both unknown identifier text and unknown identifier result
    template filter(body: untyped): untyped {.dirty.} =
      proc cb(text: string): string =
        body
      handler.filter = cb

    fullBody

    addListener(messageEvent, commandListener(handler))