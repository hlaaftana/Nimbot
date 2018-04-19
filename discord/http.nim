import httpclient, asyncdispatch, json, uri, common

proc parseResponse*(resp: AsyncResponse): JsonNode =
  result = parseJson(waitFor resp.body)

proc get*(uri: Uri): JsonNode =
  parseJson(waitFor client.http.getContent($uri))

let postHeaders = newHttpHeaders({"Content-Type": "application/json"})
proc post*(uri: Uri, data: JsonNode): Future[AsyncResponse] =
  client.http.request($uri, HttpPost, $data, postHeaders)