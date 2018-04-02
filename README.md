# Nimbot
Basic discord bot in Nim 0.18.0

This works. Requires [websocket](https://github.com/niv/websocket.nim)@#HEAD as of March 29 2018, and for optional probably not working compression you can get [zip](https://github.com/nim-lang/zip) and hope for the best

So its as easy as

```
git clone https://github.com/hlaaftana/Nimbot.git
cd Nimbot
nimble install websocket@#HEAD
nim c -d:ssl main
.\main "token"
```
