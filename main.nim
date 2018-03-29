import common, json, ws, asyncdispatch, http, uri

proc message(obj: JsonNode) =
  let content = obj["content"].getStr
  if content == "dab now":
    asyncCheck post(api / "channels" / obj["channel_id"].getStr / "messages", %*{"content": "\\*dabs now\\*"})

addListener(messageEvent, message)

asyncCheck read()
runForever()