# ComputerCraft-Tunnel-Bore

This repository contains Lua programs for use with **ComputerCraft** and **CC:Tweaked** in Minecraft. These programs automate a mining turtle to dig a 3x3 tunnel while broadcasting its progress to a base monitor.

---

## **Programs**

### 1. `mineTunnelForward.lua`
This program automates a **mining turtle** to:
- Dig a **3x3 tunnel** forward for a specified length.
- Place **torches** every 6 blocks to keep the tunnel lit.
- Monitor its **fuel level** and refuel itself using coal.
- Detect when its **inventory is full**, return to the start, and store items in a chest.
- Broadcast its **progress and status updates** to a base computer using a wireless modem.

#### **Features:**
- Digs forward, creating a 3x3 tunnel.
- Places torches for lighting at regular intervals.
- Automatically handles fuel and storage.
- Communicates progress to a **monitor setup** in the main base.

#### **Usage:**
1. Attach a **wireless modem** to the turtle.
2. Prepare the turtle inventory:
   - **Slot 16:** Torches  
   - **Slot 15:** Coal or other fuel  
   - **Slot 14:** A chest for item storage  
   - **Slots 1-13:** Leave empty for mined items.
3. Place the turtle facing the desired mining direction.
4. Run the program:
   ```lua
   mineTunnelForward
