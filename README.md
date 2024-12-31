# ComputerCraft-Tunnel-Bore

This repository contains three Lua scripts designed for automating turtle operations in Minecraft using the CC:Tweaked mod. Each script serves a specific purpose in the automation process, from GPS hosting to tunnel boring and terminal control.

## Files

### 1. `gpsTerm.lua`
- **Purpose**: Acts as a GPS host to provide positional coordinates for turtles.
- **Features**:
  - Initializes a wireless modem to operate as a GPS host.
  - Configurable for different modem sides and coordinates.
  - Essential for enabling GPS-based navigation for turtles.

### 2. `tunnelBore.lua`
- **Purpose**: Automates tunnel boring with features like auto-refueling, item depositing, and terminal command handling.
- **Features**:
  - Mines a 3x3 tunnel for a configurable length.
  - Integrates with GPS to update its position in real-time.
  - Supports terminal commands to start/stop mining and return to a specified location.
  - Automatically deposits mined items and refuels from a chest.
  - Includes A* pathfinding for navigation.
  - Debug messages for real-time updates on the turtle's actions.

### 3. `tunnelBoreTerm.lua`
- **Purpose**: Provides a user interface on a monitor to control tunnel boring turtles.
- **Features**:
  - Displays messages and logs turtle activities.
  - Interactive buttons for commands such as "Recall," "Mine," and "Exit."
  - Communicates with turtles using a wireless modem.
  - Ensures synchronization between the terminal and turtle operations.

## Usage
1. Place the scripts in your turtle's directory or the terminal computer.
2. Customize configuration options (e.g., modem side, GPS coordinates) as needed.
3. Run `gpsTerm.lua` on a computer equipped with a wireless modem to act as the GPS host.
4. Deploy turtles running `tunnelBore.lua` for mining operations.
5. Use a terminal with `tunnelBoreTerm.lua` and a connected monitor to control and monitor the turtles.

## Requirements
- [CC:Tweaked Mod](https://www.curseforge.com/minecraft/mc-mods/cc-tweaked)
- A wireless modem for communication.
- Monitors for the terminal interface.

## Contributing
Feel free to submit pull requests or issues for improvements and bug fixes.

## License
This project is licensed under the MIT License.
