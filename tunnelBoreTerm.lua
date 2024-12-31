-- Tunnel Bore Terminal Program for CC:Tweaked
-- Displays messages and provides buttons to control turtles

-- Configuration
local modemSide = "front" -- Side with the wireless modem
local monitorName = "top" -- Replace with the correct monitor name
local monitor = peripheral.wrap(monitorName) -- Wrap the monitor peripheral
local maxLines = 6 -- Maximum lines of messages to display before clearing
local messageStartLine = 4 -- Line number to start displaying messages (below buttons)
local protocol = "TurtleControl" -- Protocol for communication

-- Message buffer
local messageBuffer = {}

-- Initialization
if not peripheral.isPresent(modemSide) then
    print("[ERROR] Modem not found on side: " .. modemSide)
    return
end
print("[DEBUG] Modem detected on side: " .. modemSide)

if not monitor then
    print("[ERROR] Monitor not found!")
    return
end
print("[DEBUG] Monitor initialized successfully.")

rednet.open(modemSide)
monitor.clear()
monitor.setTextScale(1) -- Ensure proper text size for touch-enabled mode

-- Function to display static elements
local function drawStaticElements()
    monitor.setCursorPos(1, 1)
    monitor.clearLine()
    monitor.write("Listening...")
    monitor.setCursorPos(1, 2)
    monitor.clearLine()
    monitor.write("[ Recall ]  [ Mine ]  [ Exit ]") -- Draw the buttons
end

-- Function to update the display with the message buffer
local function updateDisplay()
    -- Draw static elements (Listening and Buttons)
    drawStaticElements()

    -- Clear only the lines below the buttons for new messages
    for i = messageStartLine, messageStartLine + maxLines - 1 do
        monitor.setCursorPos(1, i)
        monitor.clearLine()
    end

    -- Display messages from the buffer
    for i, msg in ipairs(messageBuffer) do
        local lineIndex = messageStartLine + i - 1
        if lineIndex <= messageStartLine + maxLines - 1 then
            monitor.setCursorPos(1, lineIndex)
            monitor.write(msg)
        end
    end
end

-- Add a message to the buffer and refresh the display
local function addMessage(message)
    table.insert(messageBuffer, os.date("[%H:%M:%S] ") .. message)
    if #messageBuffer > maxLines then
        table.remove(messageBuffer, 1) -- Remove the oldest message
    end
    updateDisplay()
end

-- Command Function
local function sendCommand(command)
    print("[DEBUG] Sending command: " .. command) -- Debug
    rednet.broadcast(command, protocol)
    addMessage("Sent command: " .. command)
end

-- Main Loop
while true do
    -- Ensure display is updated at least once per iteration
    updateDisplay()

    local event, param1, param2, param3 = os.pullEvent()

    if event == "monitor_touch" then
        if param3 == 2 then -- y-coordinate of the button row
            if param2 >= 1 and param2 <= 9 then
                print("[DEBUG] Recall button pressed.") -- Debug
                sendCommand("recall")
            elseif param2 >= 11 and param2 <= 17 then
                print("[DEBUG] Mine button pressed.") -- Debug
                sendCommand("mine")
            elseif param2 >= 20 and param2 <= 26 then
                print("[DEBUG] Exit button pressed.") -- Debug
                addMessage("Exiting program...")
                break
            end
        end
    elseif event == "rednet_message" then
        local senderId, message, receivedProtocol = param1, param2, param3
        if receivedProtocol == protocol then
            addMessage("Turtle " .. senderId .. ": " .. message)
            print("[DEBUG] Message received from Turtle " .. senderId .. ": " .. message)
        else
            print("[DEBUG] Message ignored due to mismatched protocol.")
        end
    end
end