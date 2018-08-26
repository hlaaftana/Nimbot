import messages, json, strutils

type
  CommandProc*[T] = proc(cachedContent: string, args: string, obj: MessageEvent): T

  Command* = object
    prefix*, info*: string
    callback*: CommandProc[void]

  CommandHandler* = object
    commands*: seq[Command]
    allowMultiple*: bool
    prefixes*: seq[string]
    predicate*: CommandProc[bool]
    filter*: proc(text: string): string {.noSideEffect.}
    noMatch*: CommandProc[void]

proc handleCommand*(hndl: CommandHandler, msg: MessageEvent) =
  var matched: bool
  let cont = msg.content
  var curr = cont
  let hf = hndl.predicate
  if not hf.isNil and not hf(cont, curr, msg):
    return
  var success = false
  for hp in hndl.prefixes:
    if curr.startsWith(hp):
      curr.removePrefix(hp)
      success = true
      break
  if not success:
    return
  for cmd in hndl.commands:
    let p = cmd.prefix
    if curr.startsWith(p):
      var args = curr
      args.removePrefix(p)
      let ended = args.len == 0
      if ended or args[0] in Whitespace:
        matched = true
        if not ended:
          args = args.strip(trailing = false)
        cmd.callback(cont, args, msg)
        if not hndl.allowMultiple:
          return
  if not matched and not hndl.noMatch.isNil:
    hndl.noMatch(cont, curr, msg)

proc filterText*(hndl: CommandHandler, text: string): string {.inline, gcsafe.} =
  if hndl.filter.isNil:
    result = text
  else:
    result = (hndl.filter)(text)

template prefix*(s: varargs[string]): untyped =
  if handler.prefixes.isNil:
    handler.prefixes = @s
  else:
    handler.prefixes.add(s)

template filter*(body: untyped): untyped =
  block:
    proc filterProc(text: string): string {.noSideEffect.} =
      let text {.inject.} = text
      body
    handler.filter = filterProc

template filter*(name, body: untyped): untyped =
  block:
    proc filterProc(text: string): string {.noSideEffect.} =
      let `name` {.inject.} = text
      body
    handler.filter = filterProc

template predicate*(body: untyped): untyped =
  block:
    proc msgProc(content, args: string, message: MessageEvent): bool =
      let
        content {.inject, used.} = content
        args {.inject, used.} = args
        message {.inject, used.} = message
      body
    handler.predicate = msgProc

template cmd*(alias: string, body: untyped): untyped =
  block:
    proc msgProc(content, args: string, message: MessageEvent): void =
      let
        content {.inject, used.} = content
        args {.inject, used.} = args
        message {.inject, used.} = message
      body
    let cmd = Command(prefix: alias, callback: msgProc)
    handler.commands.safeAdd(cmd)

template cmd*(alias: string, body: untyped, infoBody: untyped): untyped =
  block:
    proc msgProc(content, args: string, message: MessageEvent): void =
      let
        content {.inject, used.} = content
        args {.inject, used.} = args
        message {.inject, used.} = message
      body
    var command {.inject.} = Command(prefix: alias, callback: msgProc)
    template info(str: string) {.inject, used.} =
      command.info = str
    infoBody
    handler.commands.safeAdd(command)