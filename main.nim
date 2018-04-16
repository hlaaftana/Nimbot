include discordprelude

import strutils

filter:
  text.multiReplace(
    ("@everyone", "@\u200beveryone"),
    ("@here", "@\u200beveryone"))

prefix "hey lover, "

command "hows your day today":
  allow respond("\\*good lol\\*")

command "say":
  allow respond("ok i will say that, " & args)

addCommands()

allow read()
runForever()