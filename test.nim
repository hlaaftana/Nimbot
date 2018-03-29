import asyncdispatch, discordnim, strutils

proc isCommand(content: string, name: string): bool =
  (content & " ").startsWith("|>" & name & " ")

proc onMessage(s: SuperClient, m: DiscordSuperObject) =
  if s.cache.me.id == m.author.id: return
  echo m.content
  if m.content.isCommand("test"):
    asyncCheck s.channelMessageSend(m.channel_id, "Yep it works")

let s = createClient("Bot MTkzNjQ2OTI2MTkxNzg4MDMz.CnJOKQ.O45xsLBe4r8UhPugcARAX7z0YDI")

waitFor s.run()