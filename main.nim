import common, json, ws, asyncdispatch, http, uri

proc sendMessage(channelId: string, content: string, tts: bool = false): Future[Response] =
  var payload = newJObject()
  payload["content"] = %content
  if tts: payload["tts"] = %true
  post(api / "channels" / channelId / "messages", $payload)

proc reply(obj: JsonNode, content: string, tts: bool = false): Future[Response] =
  sendMessage(obj["channel_id"].getStr, content, tts)

# main bot

proc message(obj: JsonNode) =
  let content = obj["content"].getStr
  if content == "dab now":
    asyncCheck obj.reply("\\*dabs now\\*")

addListener(messageEvent, message)

asyncCheck read()
runForever()