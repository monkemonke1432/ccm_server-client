-- BRIDGE_SERVER.LUA - Bridges wired, wireless, and ender modems together
-- This server acts as a relay between different modem types
-- allowing clients on wired networks to talk to clients on wireless/ender networks

local modems = {}
local clients = {} -- Track connected clients

-- Find all attached modems
print("=== Chat Bridge Server ===")
print("Scanning for modems...")

for _, side in ipairs(peripheral.getNames()) do
  if peripheral.getType(side) == "modem" then
    local modem = peripheral.wrap(side)
    table.insert(modems, {
      side = side,
      modem = modem,
      type = modem.isWireless() and "wireless" or "wired"
    })
    modem.open(100) -- Open channel 100 on all modems
    print("Found " .. (modem.isWireless() and "wireless" or "wired") .. " modem on " .. side)
  end
end

if #modems == 0 then
  error("No modems attached", 0)
end

print("-------------------")
print("Bridge active on " .. #modems .. " modem(s)")
print("Listening on channel 100...")
print("Waiting for clients to connect...")
print("-------------------")

-- Helper function to broadcast to all modems except the source
local function broadcastToOtherModems(sourceModem, channel, message)
  for _, m in ipairs(modems) do
    if m.modem ~= sourceModem then
      m.modem.transmit(channel, 100, message)
    end
  end
end

-- Helper function to broadcast to all modems
local function broadcastToAllModems(channel, message)
  for _, m in ipairs(modems) do
    m.modem.transmit(channel, 100, message)
  end
end

-- Helper function to get modem by side
local function getModemBySide(side)
  for _, m in ipairs(modems) do
    if m.side == side then
      return m.modem
    end
  end
  return nil
end

while true do
  local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
  
  if channel == 100 and type(message) == "table" then
    local sourceModem = getModemBySide(side)
    local clientID = message.id
    local msgType = message.type
    
    if msgType == "connect" then
      -- Client connecting
      clients[clientID] = {
        nick = message.nick,
        channel = replyChannel,
        modemSide = side
      }
      print("[BRIDGE] " .. message.nick .. " connected via " .. side .. " (ID: " .. clientID .. ")")
      
      -- Send confirmation back to the client through their modem
      if sourceModem then
        sourceModem.transmit(replyChannel, 100, {
          type = "connected",
          message = "Connected to bridge server"
        })
      end
      
    elseif msgType == "disconnect" then
      -- Client disconnecting
      if clients[clientID] then
        print("[BRIDGE] " .. clients[clientID].nick .. " disconnected")
        clients[clientID] = nil
      end
      
    elseif msgType == "message" then
      -- Broadcast message to all clients on all modems
      if clients[clientID] then
        local sender = clients[clientID]
        print("[" .. sender.nick .. "]: " .. message.text)
        
        -- Create the broadcast message
        local broadcastMsg = {
          type = "message",
          nick = sender.nick,
          text = message.text
        }
        
        -- Send to all clients on all modems
        for id, client in pairs(clients) do
          if id ~= clientID then
            -- Find which modem this client is on
            local clientModem = getModemBySide(client.modemSide)
            if clientModem then
              clientModem.transmit(client.channel, 100, broadcastMsg)
            end
          end
        end
      end
      
    elseif msgType == "nick_change" then
      -- Client changing nickname
      if clients[clientID] then
        local oldNick = clients[clientID].nick
        clients[clientID].nick = message.nick
        print("[BRIDGE] " .. oldNick .. " changed nickname to " .. message.nick)
        
        -- Create system notification
        local sysMsg = {
          type = "system",
          text = oldNick .. " is now known as " .. message.nick
        }
        
        -- Notify all clients on all modems
        for id, client in pairs(clients) do
          local clientModem = getModemBySide(client.modemSide)
          if clientModem then
            clientModem.transmit(client.channel, 100, sysMsg)
          end
        end
      end
    end
  end
end
