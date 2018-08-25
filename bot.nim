import strutils
include discord/prelude

filter:
  text.multiReplace({
    "@everyone": "@\u200beveryone",
    "@here": "@\u200beveryone"
  })

prefix "hey lover, "

cmd "hows your day today":
  asyncCheck respond("\\*good lol\\*")

cmd "say":
  asyncCheck respond("ok i will say that, " & args)

init()