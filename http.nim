import httpclient, asyncdispatch, json, uri, common

let http* = newAsyncHttpClient(discordUserAgent)
http.headers = newHttpHeaders({"Authorization": token})

template get*(uri: Uri): JsonNode = parseJson(waitFor http.getContent($uri))

let postHeaders = newHttpHeaders({"Content-Type": "application/json"})
template post*(uri: Uri, data: JsonNode): auto = http.request($uri, HttpPost, $data, postHeaders)