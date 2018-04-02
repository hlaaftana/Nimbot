import common, json, ws, asyncdispatch, http, uri, message

proc handle(msg: MessageEvent) =
  let content = msg.content
  if content == "dab now":
    asyncCheck msg.reply("\\*dabs now\\*")

addListener(messageEvent, handle)

asyncCheck read()
runForever()