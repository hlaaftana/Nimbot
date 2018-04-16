import common, http, ws, messages, asyncdispatch

template get*[T](fut: Future[T]): T = waitFor(fut)
template allow*(fut: untyped): untyped = asyncCheck(fut)

proc init* =
  if handler.listener.isNil:
    addCommands()
  allow read()
  runForever()