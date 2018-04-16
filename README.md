# pkpsgpsg
Discord bot in Nim 0.18.0. Stands for Pun K Psrps So Gory Pthat Someone Goe'daway. Pack Passage Passage. Pessage Pessage.

So you found some discord libraries in nim on GitHub cuz you wanted to write a bot. You didn't like any of them because they didn't work or all of them have their own forks of websocket.nim in their repos or they're all too OOP or they just suck or whatever. Take a look at mine. Tho this isnt a library but it works and is minimal tm.
You even want some code is that what i hear???????

```nim
import strutils
include discord/prelude

prefix("!")

filter:
  text.multiReplace {
    "@everyone": "@\u200beveryone",
    "@here": "@\u200beveryone"
  }

cmd "say":
  allow respond(args) # allow is alias for asyncCheck for ignoring result of async procs

init()
```

Installation:

```
git clone https://github.com/hlaaftana/pkpsgpsg
cd pkpsgpsg
nimble install websocket@#HEAD # websocket has some issues so its important to get the latest version possible

nim c -d:ssl main
./main # file called bot.json with {"token": <token>} has to be in the same folder

# or

nim c -d:ssl -d:discordcliconfig main
./main <token>
```

For compression if you want, you can get [zip](https://github.com/nim-lang/zip) and zlib1.dll and `-d:discordcompress` and hope for the best cuz it probably wont work right now.

If you don't want to write a bot and want a general API for discord, look at the http and ws modules and get what you need.