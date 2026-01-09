-- SERVER.LUA - Run this on the server computer
local modem = peripheral.find("modem") or error("No modem attached", 0)
modem.open(100) -- Server listens on channel 100

local clients = {} -- Track connected clients

print("=== Chat Server ===")
print("Listening on channel 100...")
print("Waiting for clients to connect...")
print("-------------------")

while true do
  local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
  
  if channel == 100 and type(message) == "table" then
    local clientID = message.id
    local msgType = message.type
    
    if msgType == "connect" then
      -- Client connecting
      clients[clientID] = {
        nick = message.nick,
        channel = replyChannel
      }
      print("[SERVER] " .. message.nick .. " connected (ID: " .. clientID .. ")")
      
      -- Send confirmation
      modem.transmit(replyChannel, 100, {
        type = "connected",
        message = "Connected to server"
      })
      
    elseif msgType == "disconnect" then
      -- Client disconnecting
      if clients[clientID] then
        print("[SERVER] " .. clients[clientID].nick .. " disconnected")
        clients[clientID] = nil
      end
      
    elseif msgType == "message" then
      -- Broadcast message to all other clients
      if clients[clientID] then
        local sender = clients[clientID]
        print("[" .. sender.nick .. "]: " .. message.text)
        
        -- Send to all clients except sender
        for id, client in pairs(clients) do
          if id ~= clientID then
            modem.transmit(client.channel, 100, {
              type = "message",
              nick = sender.nick,
              text = message.text
            })
          end
        end
      end
      
    elseif msgType == "nick_change" then
      -- Client changing nickname
      if clients[clientID] then
        local oldNick = clients[clientID].nick
        clients[clientID].nick = message.nick
        print("[SERVER] " .. oldNick .. " changed nickname to " .. message.nick)
        
        -- Notify all clients
        for id, client in pairs(clients) do
          modem.transmit(client.channel, 100, {
            type = "system",
            text = oldNick .. " is now known as " .. message.nick
          })
        end
      end
    end
  end
end
