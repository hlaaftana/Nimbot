import strutils
include discord/prelude

filter:
  text.multiReplace({
    "@everyone": "@\u200beveryone",
    "@here": "@\u200beveryone"
  })

prefix "hey lover, "

cmd "hows your day today":
  allow respond("\\*good lol\\*")

cmd "say":
  allow respond("ok i will say that, " & args)

init()