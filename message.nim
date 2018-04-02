import json, http, uri, common

type MessageEvent* = distinct JsonNode

proc channelId*(msg: MessageEvent): string =
  JsonNode(msg)["channel_id"].getStr()

proc content*(msg: MessageEvent): string =
  JsonNode(msg)["content"].getStr()

proc sendMessage*(channelId: string, content: string, tts: bool = false): auto =
  var payload = newJObject()
  payload["content"] = %content
  if tts: payload["tts"] = %true
  post(api / "channels" / channelId / "messages", payload)

template reply*(obj: MessageEvent, content: string, tts: bool = false): auto =
  sendMessage(obj.channelId, content, tts)