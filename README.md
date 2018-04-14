# pkpsgpsg
Basic discord bot in Nim 0.18.0. Stands for Pun Krk PgPSspspsğgspsğgpsğgspgğs Sick Gore Pun2 Some Gor. Now say it after me. Pack Passage Passage. Pessage Pessage.

Now you might be like "Wow i found this niche called nim, i should write a discord library for it
so people would like me, but i should search on github whether someone made it first already first"
or maybe youre like "nim is a cool language i should write a discord bot in it.".".".". Either way,
youre in the right store, at the right time? I dont even fucking care Plagayariyese the entire repo
and never mention me if you want to but its not like i dont want to be associated with this

Requires [websocket](https://github.com/niv/websocket.nim)@#HEAD as of March 29 2018, and for optional probably not working compression you can get [zip](https://github.com/nim-lang/zip) and hope for the best

So its as easy as

```
git clone https://github.com/hlaaftana/pkpsgpsg
cd pkpsgpsg
nimble install websocket@#HEAD

nim c -d:ssl main
./main # file called bot.json with {"token": <token>} has to be in the same folder

# or

nim c -d:ssl -d:discordcli main
./main <token>
```
