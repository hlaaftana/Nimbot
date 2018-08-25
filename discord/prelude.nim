import common, http, ws, messages, asyncdispatch, json, tables

template get*[T](fut: Future[T]): T = waitFor(fut)

proc init* =
  if handler.listener.isNil:
    addCommands()
  asyncCheck read()
  runForever()