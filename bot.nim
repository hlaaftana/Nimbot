import httpclient, strutils, times, uri, json, asyncdispatch
import discord/[discord, arguments, commands, http, messages, ws]

proc evalNim(code: string, target = "c"): tuple[compileLog, log: string] =
  let http = newAsyncHttpClient()
  try:
    let js = %* {"code": code, "compilationTarget": "c"}
    let resp = waitFor http.post("https://play.nim-lang.org/compile", $js)
    let res = parseJson(waitFor resp.body)
    result = (res["compileLog"].getStr, res["log"].getStr)
  except:
    result = ("", "")

proc evalGroovy(code: string): tuple[result, output, stacktrace: string, errorcode: string] =
  try:
    let http = newAsyncHttpClient()
    let resp = waitFor http.request("https://groovyconsole.appspot.com/executor.groovy?script=" & encodeUrl(code), HttpPost,
      "{}")
    result.errorcode = $resp.code & "\n" & waitFor resp.body
    let res = parseJson(waitFor resp.body)
    result.result = res["executionResult"].getStr
    result.output = res["outputText"].getStr
    result.stacktrace = res["stacktraceText"].getStr
  except:
    discard

proc main =
  var
    handler: CommandHandler
    ready: JsonNode
    dispatcher: ListenerDispatcher
    instance: DiscordInstance

  dispatcher.init()
  dispatcher.addListener("READY") do (node: JsonNode):
    ready = node
  dispatcher.addListener("MESSAGE_CREATE") do (node: JsonNode):
    handler.handleCommand(MessageEvent(node))

  template respond(cont: string, tts = false): untyped =
    instance.http.reply(message, filterText(handler, cont), tts)

  template typing() =
    instance.http.typing(message.channelId)

  filter:
    result = text.multiReplace({
      "@everyone": "@\u200beveryone",
      "@here": "@\u200beveryone"
    })
    if result.len >= 1_700:
      result = "text is too big to post"

  predicate:
    JsonNode(message)["author"]["id"] != ready["user"]["id"]

  prefix "v<", "v>"

  cmd "cmds":
    var res = "cmds:"
    for c in handler.commands:
      res.add(' ')
      res.add(c.prefix)
    asyncCheck respond(res)
  do:
    info "lists all commands"

  cmd "info":
    if args.len == 0:
      asyncCheck respond("""this is claudes bot, you call it by doing v<command
for all commands do v<cmds
why did i choose v<? because i dont have to press shift or ctrl or whatever to type it
normally id go with something like "poo " but itd come out of nowhere if someone typed poo naturally
source code at https://github.com/hlaaftana/pkpsgpsg
nim version is """ & NimVersion)
    else:
      for c in handler.commands:
        if c.prefix == args:
          if c.info.len == 0:
            asyncCheck respond("no info about that command")
          else:
            asyncCheck respond(args & ": " & c.info)
          return
      asyncCheck respond("couldnt find command " & args)
  do:
    info "gives info about the bot, or about a command if you ask"

  cmd "say":
    asyncCheck respond(args)
  do:
    info "copies you"

  cmd "save":
    var a = newArguments(args)
    let arg = a.next
    case arg
    of "get":
      let name = escapeJson(a.next)[1..^2]
      var by: string
      case a.rest
      of nil, "", "me":
        by = JsonNode(message)["author"]["id"].getStr
      of "anyone":
        by = ""
      elif a.rest.allCharsInSet({'0'..'9'}):
        by = a.rest
      else:
        asyncCheck respond("the second argument is supposed to be an ID, " &
          "you must have put in a space by accident. to keep the spaces, put the name of the save in quotes")
        return
      var file = open("data/saved")
      var ourId = false
      for line in file.lines:
        case line[0]
        of '0'..'9':
          ourId = by == "" or line == by
        of '|':
          if ourId:
            var escaped = false
            var recorded = ""
            for i in 1..line.high:
              let ch = line[i]
              if not escaped and ch == '"':
                if recorded == name:
                  asyncCheck respond(name & ": " & parseJson(line[i..^1]).getStr)
                  file.close()
                  return
                else: break
              recorded.add(ch)
              escaped = not escaped and ch == '\\'
        else:
          discard
      file.close()
      asyncCheck respond("couldnt find " & name)
    of "set":
      let name = escapeJson(a.next)[1..^2]
      let val = a.rest
      var str = ""
      let ourId = JsonNode(message)["author"]["id"].getStr
      var isOurId = false
      var done = false
      for line in "data/saved".lines:
        if done:
          str.add(line)
          str.add("\n")
        else:
          case line[0]
          of '0'..'9':
            if isOurId:
              str.add("|" & name & $(%val) & "\n")
              str.add("\n")
              done = true
            else:
              isOurId = line == ourId
            str.add(line)
            str.add("\n")
          of '|':
            var
              i = 1
              n = ""
              escaped = false
            while i < line.len:
              let ch = line[i]
              if not escaped and ch == '"':
                break
              else:
                n.add(ch)
              escaped = not escaped and ch == '\\'
              inc i
            if name == n:
              str.add("|" & name & $(%(val % parseJson(line[i .. ^1]).getStr)) & "\n")
              done = true
            else:
              str.add(line)
            str.add("\n")
          elif not line.allCharsInSet(Whitespace):
            str.add(line.strip)
            str.add("\n")
      if not done:
        if not isOurId:
          str.add(ourId)
          str.add("\n")
        str.add("|" & name & $(%val) & "\n")
        str.add("\n")
      writeFile("data/saved", str)
      asyncCheck respond("saved to " & name)
    of "delete":
      let name = escapeJson(a.next)[1..^2]
      var str = ""
      let ourId = JsonNode(message)["author"]["id"].getStr
      var isOurId, successful, done = false
      for line in "data/saved".lines:
        if done:
          str.add(line)
          str.add("\n")
        else:
          case line[0]
          of '0'..'9':
            if isOurId:
              done = true
            else:
              isOurId = line == ourId
            str.add(line)
            str.add("\n")
          of '|':
            var
              i = 1
              n = ""
              escaped = false
            while i < line.len:
              let ch = line[i]
              if not escaped and ch == '"':
                break
              else:
                n.add(ch)
              escaped = not escaped and ch == '\\'
              inc i
            if name != n:
              str.add(line)
              str.add("\n")
            else:
              successful = true
          else:
            str.add(line)
            str.add("\n")
      writeFile("data/saved", str)
      if successful:
        asyncCheck respond("deleted " & name)
      else:
        asyncCheck respond(name & " didn't exist")
    of "list":
      var by: string
      case a.rest
      of nil, "", "me":
        by = JsonNode(message)["author"]["id"].getStr
      of "anyone":
        by = ""
      elif a.rest.allCharsInSet({'0'..'9'}):
        by = a.rest
      else:
        asyncCheck respond("list is supposed to take an ID, " &
          "you must have put in a name or whatever, i dont like those yet")
        return
      var ourId = false
      var names = newSeq[string]()
      for line in "data/saved".lines:
        case line[0]
        of '0'..'9':
          ourId = by == "" or line == by
        of '|':
          if ourId:
            var escaped = false
            var recorded = ""
            for i in 1..line.high:
              let ch = line[i]
              if not escaped and ch == '"':
                names.add(recorded)
                break
              recorded.add(ch)
              escaped = not escaped and ch == '\\'
        else:
          discard
      if names.len != 0:
        asyncCheck respond("got names: " & names.join(", "))
      elif by != "":
        asyncCheck respond(by & " had no saves")
      else:
        asyncCheck respond("no one had saves (?)")
    else:
      asyncCheck respond("i dont have option '" & arg & "' tell me if it should be added")
  do:
    info """lets you save snippets of text
usage:
`save set name text  -- saves text to name. note that you can use $1 to replace text,
                    -- so to append you could do "save set name $1 newtext"
save get name       -- gets text of name
save get name ID    -- gets text of name from saves of person with ID, ID can also be "anyone" or "me"
save delete name    -- deletes text from name
save list           -- lists your saves
save list ID        -- lists saves of person with ID, can also be anyone or me`"""

  cmd "gccollect":
    GC_fullCollect()

  cmd "die":
    if JsonNode(message)["author"]["id"].getStr == "98457401363025920":
      quit(-1)
    else:
      asyncCheck respond("i cant die,")

  cmd "ping":
    var msg = "started"
    let a = cpuTime()
    let m = waitFor respond(msg)
    let b = cpuTime()
    msg.add("\nposting took " & $(b - a) & " seconds")
    let c = cpuTime()
    let mn = parseJson(waitFor m.body)
    discard waitFor(instance.http.edit(mn, msg))
    let d = cpuTime()
    msg.add("\nediting took " & $(d - c) & " seconds")
    asyncCheck instance.http.edit(mn, msg)

  cmd "nim+":
    typing
    let (compileLog, log) = evalNim(args)
    if log.len == 0:
      asyncCheck respond("try again later the nim playground is shaky")
    else:
      asyncCheck respond("compile log:\n" & compileLog & "\noutput:\n" & log)
  do:
    info "compiles nim code via the playground and shows the compile output"

  cmd "nim":
    typing
    let (_, log) = evalNim(args)
    if log.len == 0:
      asyncCheck respond("try again later the nim playground is shaky")
    else:
      asyncCheck respond("output:\n" & log)
  do:
    info "compiles nim code via the playground, for compile output use nim+"

  cmd "groovy":
    typing
    let (result, output, stack, errorcode) = evalGroovy(args)
    var msg = ""
    if result.len != 0:
      msg.add("result:\n")
      msg.add(result)
      msg.add("\n")
    if output.len != 0:
      msg.add("output:\n")
      msg.add(output)
      msg.add("\n")
    if stack.len != 0:
      msg.add("stacktrace:\n")
      msg.add(stack)
      msg.add("\n")
    if msg.len == 0:
      asyncCheck respond("got empty response: " & errorcode)
    else:
      asyncCheck respond(msg)
  do:
    info "evaluates groovy code via groovyconsole.appspot.com"

  init(dispatcher, json.parseFile("bot.json")["token"].getStr, instance)
  runForever()

main()