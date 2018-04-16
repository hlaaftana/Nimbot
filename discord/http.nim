import httpclient, asyncdispatch, json, uri, common

let http* = newAsyncHttpClient(discordUserAgent)
http.headers = newHttpHeaders({"Authorization": token})

proc parseResponse*(resp: AsyncResponse): JsonNode =
  result = parseJson(waitFor resp.body)

proc get*(uri: Uri): JsonNode =
  parseJson(waitFor http.getContent($uri))

let postHeaders = newHttpHeaders({"Content-Type": "application/json"})
proc post*(uri: Uri, data: JsonNode): Future[AsyncResponse] =
  http.request($uri, HttpPost, $data, postHeaders)