-- Tunnel Bore Mining Program with Terminal Control
-- Mines a 3x3 tunnel, auto-refuels, deposits items, and reacts to terminal commands
-- Configuration
local tunnelLength = 100 -- Length of tunnel to dig
local chestPos = vector.new(167, -5, -64) -- Starting chest position
local modemSide = "left" -- Side with wireless modem
local cachedWorld = {}
local facing = 0 -- 0 = North, 1 = East, 2 = South, 3 = West

-- State Variables
local currentPos = vector.new(0, 0, 0) -- Empty Vector to be updated using the GPS
local direction = vector.new(0, 0, 1) -- Facing forward
local miningActive = false

-- Broadcast Function Init
local function broadcast(message)
    if peripheral.isPresent(modemSide) then
        rednet.broadcast(message, "TurtleControl")
        print("[Broadcast]: " .. message) -- Debug message on the turtle's terminal
    else
        print("[ERROR] No modem found on side: " .. modemSide)
    end
end

local function updateCurrentPosition()
    local x, y, z = gps.locate(5)
    if x and y and z then
        currentPos = vector.new(math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5))
        print("[DEBUG] Updated current position: " .. currentPos:tostring())
        return true
    else
        print("[ERROR] Failed to update position. GPS locate failed.")
        return false
    end
end

-- Movement Functions
local function moveForward()
    if turtle.forward() then
        updateCurrentPosition() -- Update position using GPS after moving
        return true
    end
    return false
end

local function moveBack()
    if turtle.back() then
        updateCurrentPosition() -- Update position using GPS after moving
        return true
    end
    return false
end

local function turnLeft()
    turtle.turnLeft()
    facing = (facing - 1) % 4
end

local function turnRight()
    turtle.turnRight()
    facing = (facing + 1) % 4
end

local function moveUp()
    if turtle.up() then
        updateCurrentPosition()
        return true
    end
    return false
end

local function moveDown()
    if turtle.down() then
        updateCurrentPosition()
        return true
    end
    return false
end

local function autoCalibrate()
    print("[DEBUG] Starting auto-calibration...")

    -- Get initial GPS position
    local x1, y1, z1 = gps.locate(5)
    if not x1 or not y1 or not z1 then
        print("[ERROR] GPS calibration failed. No initial position.")
        return false
    end
    print(string.format("[DEBUG] Initial GPS Position: x=%.2f, y=%.2f, z=%.2f", x1, y1, z1))

    -- Try moving forward or turning in other directions if blocked
    for attempt = 1, 4 do
        print(string.format("[DEBUG] Calibration attempt %d...", attempt))

        -- Attempt to move forward
        if moveForward() then
            os.sleep(1) -- Allow GPS to stabilize
            local x2, y2, z2 = gps.locate(5)
            if x2 and y2 and z2 then
                -- Calculate movement deltas
                local dx, dz = x2 - x1, z2 - z1
                if math.abs(dx) > math.abs(dz) then
                    facing = dx > 0 and 1 or 3 -- East or West
                else
                    facing = dz > 0 and 2 or 0 -- South or North
                end
                print(string.format("[DEBUG] Facing direction set to: %d", facing))

                -- Move back to the original position
                if moveBack() then
                    print("[DEBUG] Successfully moved back to the original position.")
                    return true
                else
                    print("[ERROR] Failed to move back to the original position.")
                end
            else
                print("[ERROR] GPS calibration failed after moving forward.")
                moveBack() -- Attempt to move back regardless
            end
        else
            print("[DEBUG] Unable to move forward. Turning to try a different direction.")
        end

        -- Turn to try a new direction
        turnRight()
    end

    -- If all attempts fail
    print("[ERROR] Auto-calibration failed after trying all directions.")
    return false
end

local function turnTo(targetFacing)
    local diff = (targetFacing - facing) % 4
    if diff == 1 then
        turnRight()
    elseif diff == 2 then
        turnRight()
        turnRight()
    elseif diff == 3 then
        turnLeft()
    end
    facing = targetFacing % 4
    print(string.format("[DEBUG] Turned to facing: %d (Target: %d)", facing, targetFacing))
end

local function positionsEqual(pos1, pos2, tolerance)
    tolerance = tolerance or 0.1 -- Default tolerance
    return math.abs(pos1.x - pos2.x) <= tolerance and math.abs(pos1.y - pos2.y) <= tolerance and
               math.abs(pos1.z - pos2.z) <= tolerance
end

local function isCloseEnough(pos1, pos2, threshold)
    return math.abs(pos1.x - pos2.x) <= threshold and math.abs(pos1.y - pos2.y) <= threshold and
               math.abs(pos1.z - pos2.z) <= threshold
end

local function moveToWithThreshold(target, threshold)
    print("[DEBUG] Moving to target within threshold: " .. threshold)
    while not isCloseEnough(currentPos, target, threshold) do
        moveToCoordinates(target)
    end
    print("[DEBUG] Target reached within threshold.")
end

-- Heuristic A* For Movement
local function heuristic(a, b)
    local distance = math.abs(a.x - b.x) + math.abs(a.y - b.y) + math.abs(a.z - b.z)
    -- print(string.format("[DEBUG] Heuristic distance from %s to %s: %d", a:tostring(), b:tostring(), distance))
    return distance
end

local function aStarPathfinding(start, goal)
    local openSet = {
        [start:tostring()] = start
    }
    local cameFrom = {}
    local gScore = {
        [start:tostring()] = 0
    }
    local fScore = {
        [start:tostring()] = heuristic(start, goal)
    }
    local closedSet = {}
    local iterations = 0
    local maxIterations = 1000 -- Prevent infinite loops

    while next(openSet) do
        local current, currentKey = nil, nil
        for key, node in pairs(openSet) do
            if not current or fScore[key] < fScore[currentKey] then
                current = node
                currentKey = key
            end
        end

        if current and current:tostring() == goal:tostring() then
            local path = {}
            while current do
                table.insert(path, 1, current)
                current = cameFrom[current:tostring()]
            end
            print("[DEBUG] Path found: " .. textutils.serialize(path))
            return path
        end

        openSet[currentKey] = nil
        closedSet[current:tostring()] = true

        for _, neighbor in ipairs({vector.new(current.x + 1, current.y, current.z),
                                   vector.new(current.x - 1, current.y, current.z),
                                   vector.new(current.x, current.y + 1, current.z),
                                   vector.new(current.x, current.y - 1, current.z),
                                   vector.new(current.x, current.y, current.z + 1),
                                   vector.new(current.x, current.y, current.z - 1)}) do
            local neighborKey = neighbor:tostring()
            -- Skip neighbors marked as chests
            if cachedWorld[neighborKey] == "chest" then
                goto continue
            end
            if closedSet[neighborKey] then
                goto continue
            end

            local tentativeGScore = gScore[currentKey] + 1
            if not gScore[neighborKey] or tentativeGScore < gScore[neighborKey] then
                cameFrom[neighborKey] = current
                gScore[neighborKey] = tentativeGScore
                fScore[neighborKey] = tentativeGScore + heuristic(neighbor, goal)
                openSet[neighborKey] = neighbor
            end

            ::continue::
        end

        iterations = iterations + 1
        if iterations > maxIterations then
            print("[ERROR] A* exceeded maximum iterations.")
            return {}
        end
    end

    print("[ERROR] No path found.")
    return {}
end

local function debugPathfinding(start, goal)
    print("[DEBUG] Pathfinding from: " .. start:tostring() .. " to: " .. goal:tostring())
    if positionsEqual(start, goal) then
        print("[DEBUG] Start and goal are the same. No movement required.")
        return {}
    end
    local path = aStarPathfinding(start, goal)
    if #path == 0 then
        print("[ERROR] Pathfinding failed. No path found.")
    else
        print("[DEBUG] Path calculated: " .. textutils.serialize(path))
    end
    return path
end

local function moveToCoordinates(target)
    print(string.format("[DEBUG] Moving to target: %s from current: %s", target:tostring(), currentPos:tostring()))
    while not positionsEqual(currentPos, target) do
        local dx = target.x - currentPos.x
        local dz = target.z - currentPos.z
        local dy = target.y - currentPos.y

        if dx ~= 0 then
            turnTo(dx > 0 and 1 or 3) -- East or West
            if turtle.detect() then
                local success, data = turtle.inspect()
                if success and data.name:find("chest") then
                    broadcast("Encountered a chest. Avoiding it...")
                    return false -- Recalculate path
                else
                    turtle.dig()
                end
            end
            if not moveForward() then
                return false
            end
        elseif dz ~= 0 then
            turnTo(dz > 0 and 2 or 0) -- South or North
            if turtle.detect() then
                local success, data = turtle.inspect()
                if success and data.name:find("chest") then
                    broadcast("Encountered a chest. Avoiding it...")
                    return false -- Recalculate path
                else
                    turtle.dig()
                end
            end
            if not moveForward() then
                return false
            end
        elseif dy ~= 0 then
            if dy > 0 then
                if turtle.detectUp() then
                    local success, data = turtle.inspectUp()
                    if success and data.name:find("chest") then
                        broadcast("Encountered a chest above. Avoiding it...")
                        return false -- Recalculate path
                    else
                        turtle.digUp()
                    end
                end
                if not moveUp() then
                    return false
                end
            else
                if turtle.detectDown() then
                    local success, data = turtle.inspectDown()
                    if success and data.name:find("chest") then
                        broadcast("Encountered a chest below. Avoiding it...")
                        return false -- Recalculate path
                    else
                        turtle.digDown()
                    end
                end
                if not moveDown() then
                    return false
                end
            end
        end

        updateCurrentPosition()
        print(string.format("[DEBUG] Current position after move: %s", currentPos:tostring()))
    end
    print("[DEBUG] Reached target: " .. target:tostring())
    return true
end

-- Utility Functions

-- Modem Initialization Function
local function initializeModem()
    if not peripheral.isPresent(modemSide) then
        print("[ERROR] No modem detected on side: " .. modemSide)
        return false
    end
    rednet.open(modemSide)
    print("[DEBUG] Modem initialized on side: " .. modemSide)
    return true
end

local function detectWorld()
    local position = currentPos:tostring()
    if turtle.detect() then
        local success, data = turtle.inspect()
        if success and data.name:find("chest") then
            cachedWorld[position] = "chest" -- Mark chest position
            broadcast("Detected a chest at position: " .. position)
        else
            cachedWorld[position] = 1 -- Blocked (non-chest)
        end
    else
        cachedWorld[position] = 0 -- Free
    end
end

local function depositItems()
    broadcast("Depositing all items...")

    -- Helper function to check if a block is a chest
    local function getChestData(inspectFunc)
        local success, data = inspectFunc()
        if success and data.name:find("chest") then
            return data -- Return metadata of the chest
        end
        return nil -- Explicitly return nil if no chest is found
    end

    -- Detect and align with the chest
    local chestData = nil
    if turtle.inspect then
        chestData = getChestData(turtle.inspect)
    end
    if not chestData and turtle.inspectUp then
        chestData = getChestData(turtle.inspectUp)
    end
    if not chestData and turtle.inspectDown then
        chestData = getChestData(turtle.inspectDown)
    end
    if not chestData then
        -- Rotate to check each side for a chest
        for i = 1, 4 do
            chestData = getChestData(turtle.inspect)
            if chestData then
                break
            end
            turtle.turnRight()
        end
    end

    -- If no chest is found, broadcast an error
    if not chestData then
        broadcast("No chest detected around the turtle.")
        return false
    end

    -- Extract the number of slots from the chest metadata
    local chestSlots = chestData.metadata and chestData.metadata.slots or 27 -- Default to 27 slots (standard chest)
    broadcast("Detected chest with " .. chestSlots .. " slots.")

    -- Transfer items from turtle to chest
    local allDeposited = true
    for turtleSlot = 1, 16 do
        turtle.select(turtleSlot)
        local itemDetail = turtle.getItemDetail()
        if itemDetail then
            local deposited = false
            -- Try to transfer the item to each chest slot
            for chestSlot = 1, chestSlots do
                if turtle.transferTo(chestSlot) then
                    deposited = true
                    break
                end
            end

            -- If unable to deposit this item, flag it
            if not deposited then
                allDeposited = false
                broadcast("Failed to deposit item: " .. itemDetail.name)
            end
        end
    end

    -- Final result broadcast
    if allDeposited then
        broadcast("All items successfully deposited.")
    else
        broadcast("Some items could not be deposited. Chest may be full.")
    end

    return allDeposited
end

local function refuelFromChest()
    broadcast("Preparing to deposit all items and retrieve coal from chest...")

    -- Helper function to check if a block is a chest
    local function isChest(inspectFunc)
        local success, data = inspectFunc()
        if success and data.name:find("chest") then
            return true
        end
        return false
    end

    -- Detect chest around the turtle
    local chestDetected = false
    if isChest(turtle.inspect) then
        chestDetected = "front"
    elseif isChest(turtle.inspectUp) then
        chestDetected = "up"
    elseif isChest(turtle.inspectDown) then
        chestDetected = "down"
    else
        -- Rotate to find a chest
        for i = 1, 4 do
            if isChest(turtle.inspect) then
                chestDetected = "front"
                break
            end
            turnRight()
        end
    end

    -- If no chest is found, broadcast an error
    if not chestDetected then
        broadcast("No chest detected. Cannot deposit items or retrieve coal.")
        return false
    end

    -- Deposit all items into the chest
    broadcast("Depositing all items into the chest...")
    for slot = 1, 16 do
        turtle.select(slot)
        if chestDetected == "front" then
            turtle.drop()
        elseif chestDetected == "up" then
            turtle.dropUp()
        elseif chestDetected == "down" then
            turtle.dropDown()
        end
    end

    -- Ensure slot 1 is selected for coal retrieval
    turtle.select(1)

    -- Check how much coal the turtle already has
    local totalCoal = 0
    for i = 1, 16 do
        local itemDetail = turtle.getItemDetail(i)
        if itemDetail and (itemDetail.name == "minecraft:coal" or itemDetail.name == "minecraft:charcoal") then
            totalCoal = totalCoal + itemDetail.count
        end
    end

    -- If already has a full stack of coal, do nothing
    if totalCoal >= 64 then
        broadcast("Turtle already has a full stack of coal.")
        return true
    end

    -- Calculate how much coal is needed
    local coalNeeded = 64 - totalCoal
    broadcast("Turtle needs " .. coalNeeded .. " more coal to complete a stack.")

    -- Retrieve the necessary amount of coal from the chest
    if chestDetected == "front" then
        if not turtle.suck(coalNeeded) then
            broadcast("Failed to grab the required coal from the chest. Please check the chest!")
            return false
        end
    elseif chestDetected == "up" then
        if not turtle.suckUp(coalNeeded) then
            broadcast("Failed to grab the required coal from the chest above. Please check the chest!")
            return false
        end
    elseif chestDetected == "down" then
        if not turtle.suckDown(coalNeeded) then
            broadcast("Failed to grab the required coal from the chest below. Please check the chest!")
            return false
        end
    end

    -- Verify if enough coal was retrieved
    totalCoal = 0
    for i = 1, 16 do
        local itemDetail = turtle.getItemDetail(i)
        if itemDetail and (itemDetail.name == "minecraft:coal" or itemDetail.name == "minecraft:charcoal") then
            totalCoal = totalCoal + itemDetail.count
        end
    end

    if totalCoal >= 64 then
        broadcast("Successfully retrieved coal to complete a full stack.")
        return true
    else
        broadcast("Failed to retrieve enough coal. Turtle now has " .. totalCoal .. " coal.")
        return false
    end
end

local function refuel()
    for i = 1, 16 do
        turtle.select(i)
        if turtle.refuel(0) then
            broadcast("Refueling...")
            while turtle.getFuelLevel() < tunnelLength * 3 do
                if not turtle.refuel(1) then
                    broadcast("Out of fuel!")
                    return false
                end
            end
            broadcast("Refueled successfully.")
            return true
        end
    end
    return refuelFromChest()
end

-- Digging Functions
local function digRow()
    turnRight()
    if turtle.detect() then
        turtle.dig()
    end
    turnLeft()
    turnLeft()
    if turtle.detect() then
        turtle.dig()
    end
    turnRight()
end

local function digBottomUp()
    if turtle.detect() then
        turtle.dig()
    end
    moveForward()
    detectWorld()
    digRow()
    if turtle.detectUp() then
        turtle.digUp()
    end
    moveUp()
    detectWorld()
    digRow()
    if turtle.detectUp() then
        turtle.digUp()
    end
    moveUp()
    detectWorld()
    digRow()
end

local function digTopBottom()
    if turtle.detect() then
        turtle.dig()
    end
    moveForward()
    detectWorld()
    digRow()
    if turtle.detectDown() then
        turtle.digDown()
    end
    moveDown()
    detectWorld()
    digRow()
    if turtle.detectDown() then
        turtle.digDown()
    end
    moveDown()
    detectWorld()
    digRow()
end

-- Terminal Command Listener
local function listenForCommands()
    if not peripheral.isPresent(modemSide) then
        print("[ERROR] No modem detected on side: " .. modemSide)
        return
    end

    rednet.open(modemSide)
    broadcast("Turtle is online and ready for commands.")
    print("[DEBUG] Broadcasted online message.")

    -- Continuously listen for commands
    while true do
        local senderId, command, protocol = rednet.receive("TurtleControl", 10) -- 10-second timeout
        if command then
            print("[DEBUG] Command received: " .. tostring(command) .. " from sender: " .. senderId)
            if protocol == "TurtleControl" then
                if command == "recall" then
                    print("[DEBUG] Recall command received. Returning to chest.")
                    miningActive = false
    
                    -- Ensure correct facing and position
                    if not autoCalibrate() or not updateCurrentPosition() then
                        broadcast("Calibration or GPS update failed. Cannot recall.")
                        return
                    end
    
                    -- Perform pathfinding
                    local target = vector.new(math.floor(chestPos.x + 0.5), math.floor(chestPos.y + 0.5), math.floor(chestPos.z + 0.5))
                    broadcast("Calculating path to: " .. target:tostring())
    
                    local path = aStarPathfinding(currentPos, target)
                    if #path == 0 then
                        broadcast("No path found to the chest. Cannot recall.")
                        return
                    end
    
                    -- Follow path
                    for _, step in ipairs(path) do
                        if not moveToCoordinates(step) then
                            broadcast("Failed to move to next path point: " .. step:tostring())
                            return
                        end
                    end
    
                    -- Perform deposit and refuel
                    if depositItems() then
                        if not refuelFromChest() then
                            broadcast("Failed to retrieve coal from chest.")
                        else
                            broadcast("Successfully retrieved coal and ready for next task.")
                        end
                    else
                        broadcast("Failed to deposit items. Check chest capacity.")
                    end
    
                elseif command == "mine" then
                    print("[DEBUG] Mine command received. Starting mining operation.")
                    if not autoCalibrate() or not updateCurrentPosition() then
                        broadcast("Calibration or GPS update failed. Cannot start mining.")
                        return
                    end
                
                    -- Ensure the turtle faces away from the chest before starting mining
                    local function faceAwayFromChest()
                        print("[DEBUG] Aligning turtle to face away from the chest...")
                    
                        -- Function to detect chest in the specified direction
                        local function detectChest(inspectFunc)
                            local success, data = inspectFunc()
                            if success and data.name:find("chest") then
                                return true
                            end
                            return false
                        end
                    
                        -- Check if the chest is in front, above, or below
                        if detectChest(turtle.inspect) then
                            print("[DEBUG] Chest detected in front. Turning away...")
                            turnRight()
                            turnRight() -- Turn 180 degrees
                        elseif detectChest(turtle.inspectUp) then
                            print("[DEBUG] Chest detected above. Adjusting direction...")
                            turnTo(0) -- Default to facing North when chest is above
                        elseif detectChest(turtle.inspectDown) then
                            print("[DEBUG] Chest detected below. Adjusting direction...")
                            turnTo(0) -- Default to facing North when chest is below
                        else
                            -- Rotate to find chest and then turn away
                            for i = 1, 4 do
                                if detectChest(turtle.inspect) then
                                    print("[DEBUG] Chest detected during rotation. Turning away...")
                                    turnRight()
                                    turnRight() -- Turn 180 degrees
                                    return
                                end
                                turnRight() -- Rotate to the next direction
                            end
                            print("[DEBUG] No chest detected nearby. Proceeding as is.")
                        end
                    end                    
                
                    -- Ensure facing direction is correctly set away from the chest
                    faceAwayFromChest()
                
                    -- Start mining
                    miningActive = true
                    tunnelLength = 100 -- Reset or set tunnel length for the operation
                    broadcast("Mining operation started.")
                end                
            else
                print("[DEBUG] Ignoring command due to mismatched protocol.")
            end
        end
    end        
end

-- Initialize Modem
initializeModem()

-- Main Initialization
local function initialize()
    print("[DEBUG] Waiting for GPS to stabilize...")
    os.sleep(2) -- Wait for 2 seconds

    -- Attempt to refuel before doing anything else
    print("[DEBUG] Attempting initial refuel...")
    if not refuel() then
        print("[ERROR] Initial refuel failed. Exiting...")
        return false
    end

    -- Get initial GPS position
    local x, y, z = gps.locate(5)
    if x and y and z then
        currentPos = vector.new(math.floor(x + 0.5), math.floor(y + 0.5), math.floor(z + 0.5))
        print("[DEBUG] Starting at GPS position: " .. currentPos:tostring())
    else
        print("[ERROR] Failed to get initial GPS position. Exiting...")
        return false
    end

    -- Perform auto-calibration to determine initial facing direction
    if not autoCalibrate() then
        print("[ERROR] Auto-calibration failed. Exiting...")
        return false
    end

    return true
end

-- Main Program
if not initialize() then
    return -- Exit if initialization fails
end

-- Main Program loop
parallel.waitForAny(function()
    listenForCommands()
end, function()
    while true do
        if miningActive then
            print("[DEBUG] Mining operation started.")
            if not refuel() then
                miningActive = false
                print("[DEBUG] Mining operation stopped: Out of fuel.")
            else
                -- Reset the tunnel length before mining
                tunnelLength = 100

                while miningActive and tunnelLength > 0 do
                    -- Ensure the turtle faces away from the chest it deposited into
                    local function faceAwayFromChest()
                        -- Check where the chest is relative to the turtle
                        local chestDirection = nil
                        if turtle.inspect then
                            local success, data = turtle.inspect()
                            if success and data.name:find("chest") then
                                chestDirection = "front"
                            end
                        end
                        if not chestDirection and turtle.inspectUp then
                            local success, data = turtle.inspectUp()
                            if success and data.name:find("chest") then
                                chestDirection = "up"
                            end
                        end
                        if not chestDirection and turtle.inspectDown then
                            local success, data = turtle.inspectDown()
                            if success and data.name:find("chest") then
                                chestDirection = "down"
                            end
                        end
                        if not chestDirection then
                            -- Rotate to find chest
                            for i = 1, 4 do
                                local success, data = turtle.inspect()
                                if success and data.name:find("chest") then
                                    chestDirection = "front"
                                    break
                                end
                                turnRight()
                            end
                        end

                        -- Turn opposite of the detected chest
                        if chestDirection == "front" then
                            turnRight()
                            turnRight() -- Face opposite of the chest
                        elseif chestDirection == "up" or chestDirection == "down" then
                            broadcast("[DEBUG] Chest detected above or below. Adjusting facing manually.")
                            -- Optionally, align with a horizontal direction after vertical chests
                            turnTo(0) -- Assuming 0 = North is the forward direction
                        end
                    end

                    -- Align facing before resuming mining
                    faceAwayFromChest()

                    -- Resume mining
                    print("[DEBUG] Digging... Remaining tunnel length: " .. tunnelLength)
                    digBottomUp()
                    digTopBottom()

                    -- Check if inventory is full
                    if turtle.getItemCount(16) > 0 then
                        broadcast("Inventory full. Returning to chest...")
                        local target = chestPos
                        broadcast("Calculating path to: " .. target:tostring())
                        if not moveToCoordinates(target) then
                            print("[ERROR] Failed to return to chest. Stopping mining operation.")
                            return
                        end

                        if not depositItems() then
                            print("[ERROR] Failed to deposit items. Stopping mining operation.")
                            return
                        end

                        refuelFromChest()
                        broadcast("Resuming mining operation...")
                    end

                    tunnelLength = tunnelLength - 1
                end

                -- Recalibrate facing direction after mining
                print("[DEBUG] Mining complete. Recalibrating direction...")
                autoCalibrate()

                -- Explicitly pathfind to chestPos after mining is done
                broadcast("Mining complete. Returning to chest...")
                if not moveToCoordinates(chestPos) then
                    print("[ERROR] Failed to return to chest after mining completion.")
                else
                    print("[DEBUG] Successfully returned to chest.")
                end

                refuelFromChest()
                broadcast("Operation finished. Awaiting further commands...")
                miningActive = false
            end
        else
            os.sleep(1)
        end
    end
end)