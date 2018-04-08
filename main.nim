import ws, asyncdispatch, messages, strutils

commands:
  filter:
    result = text.multiReplace(
      ("@everyone", "@\u200beveryone"),
      ("@here", "@\u200beveryone"))

  prefix "hey porn, "

  on "dab now":
    asyncCheck respond("\\*dabs now\\*")

  on "say":
    asyncCheck respond("ok i will say that, " & args)

asyncCheck read()
runForever()