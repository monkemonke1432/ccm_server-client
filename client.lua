-- CLIENT.LUA - Run this on each client computer
local modem = peripheral.find("modem") or error("No modem attached", 0)

local CLIENT_ID = os.getComputerID()
local CLIENT_CHANNEL = 100 + CLIENT_ID -- Unique channel for this client
local SERVER_CHANNEL = 100

local nickname = "User_" .. CLIENT_ID
local connected = false

modem.open(CLIENT_CHANNEL)

print("=== ComputerCraft Chat Client ===")
print("Connecting to server...")

-- Connect to server
modem.transmit(SERVER_CHANNEL, CLIENT_CHANNEL, {
  type = "connect",
  id = CLIENT_ID,
  nick = nickname
})

-- Wait for connection confirmation
local function waitForConnection()
  local timer = os.startTimer(5)
  while true do
    local event, p1, p2, p3, message = os.pullEvent()
    if event == "modem_message" and p2 == CLIENT_CHANNEL and type(message) == "table" then
      if message.type == "connected" then
        connected = true
        print("Connected! Your nickname: " .. nickname)
        print("Commands: /setnick <n>, /exit")
        print("--------------------------")
        return true
      end
    elseif event == "timer" and p1 == timer then
      print("Connection timeout. Is the server running?")
      return false
    end
  end
end

if not waitForConnection() then
  return
end

-- Function to handle incoming messages
local function receiveMessages()
  while connected do
    local event, side, channel, replyChannel, message = os.pullEvent("modem_message")
    if channel == CLIENT_CHANNEL and type(message) == "table" then
      term.clearLine()
      term.setCursorPos(1, select(2, term.getCursorPos()))
      
      if message.type == "message" then
        print("[" .. message.nick .. "]: " .. message.text)
      elseif message.type == "system" then
        print("[SYSTEM]: " .. message.text)
      end
      
      write("> ")
    end
  end
end

-- Function to handle user input and sending
local function sendMessages()
  while connected do
    write("> ")
    local input = read()
    
    if input:lower() == "/exit" then
      print("Disconnecting...")
      modem.transmit(SERVER_CHANNEL, CLIENT_CHANNEL, {
        type = "disconnect",
        id = CLIENT_ID
      })
      modem.close(CLIENT_CHANNEL)
      connected = false
      return
      
    elseif input:sub(1, 9):lower() == "/setnick " then
      local newNick = input:sub(10):match("^%s*(.-)%s*$")
      if newNick ~= "" then
        nickname = newNick
        modem.transmit(SERVER_CHANNEL, CLIENT_CHANNEL, {
          type = "nick_change",
          id = CLIENT_ID,
          nick = nickname
        })
        print("Nickname changed to: " .. nickname)
      else
        print("Usage: /setnick <nickname>")
      end
      
    elseif input ~= "" then
      modem.transmit(SERVER_CHANNEL, CLIENT_CHANNEL, {
        type = "message",
        id = CLIENT_ID,
        text = input
      })
      
      local x, y = term.getCursorPos()
      term.setCursorPos(1, y - 1)
      term.clearLine()
      print("[You]: " .. input)
    end
  end
end

parallel.waitForAny(receiveMessages, sendMessages)
