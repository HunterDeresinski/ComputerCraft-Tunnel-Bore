-- GPS Host Program for CC:Tweaked
-- Acts as a GPS host to provide coordinates to turtles

-- Configuration
local modemSide = "bottom" -- Side with the wireless modem
local gpsCoordinates = vector.new(151, 273, -45) -- Coordinates for GPS host

-- Initialization
if not peripheral.isPresent(modemSide) then
    print("[ERROR] Modem not found on side: " .. modemSide)
    return
end
print("[DEBUG] Modem detected on side: " .. modemSide)

rednet.open(modemSide)

-- Start GPS Host
print("[DEBUG] Starting GPS host at coordinates: " .. gpsCoordinates:tostring())
shell.run("gps", "host", tostring(gpsCoordinates.x), tostring(gpsCoordinates.y), tostring(gpsCoordinates.z))
