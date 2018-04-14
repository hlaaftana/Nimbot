import ws, asyncdispatch, messages, strutils

commands:
  filter:
    result = text.multiReplace(
      ("@everyone", "@\u200beveryone"),
      ("@here", "@\u200beveryone"))

  prefix "hey lover, "

  on "hows your day today":
    asyncCheck respond("\\*good lol\\*")

  on "say":
    asyncCheck respond("ok i will say that, " & args)

asyncCheck read()
runForever()