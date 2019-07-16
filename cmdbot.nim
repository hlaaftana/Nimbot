import cmd, discord/[discord, messages, http, ws]

import strutils, json, asyncdispatch

cmd "say2":
  info "say command version 2"
  asyncCheck respond(args)

proc filterText(text: string): string =
  result = text.multiReplace({
    "@everyone": "@\u200beveryone",
    "@here": "@\u200beveryone"
  })
  if result.len >= 1_700:
    result = "text is too big to post"

proc main =
  var
    ready: JsonNode
    dispatcher: ListenerDispatcher
    instance: DiscordInstance

  let config = json.parseFile("bot.json")

  dispatcher.init()
  dispatcher.addListener("READY") do (node: JsonNode):
    ready = node
  dispatcher.addListener("MESSAGE_CREATE") do (node: JsonNode):
    let msg = MessageEvent(node)
    let cont = msg.content
    var curr = cont

    # identity check
    if node["author"]["id"] == ready["user"]["id"]:
      return

    # prefixes
    if curr.startsWith(">GREENTEXT"):
      curr.removePrefix(">GREENTEXT")
    else:
      return

    template respond(cont: string, tts = false): untyped =
      instance.http.reply(message, filterText(cont), tts)

    template typing() =
      instance.http.typing(message.channelId)

    var arg = curr

    eachCommand(msg, cont, arg):
      if arg.startsWith(prefix):
        arg.removePrefix(prefix)
        let ended = arg.len == 0
        if ended or arg[0] in Whitespace:
          if not ended:
            arg = arg.strip(trailing = false)
          commandBody
          return
        arg = curr

  init(dispatcher, config["token"].getStr, instance)
  runForever()

main()