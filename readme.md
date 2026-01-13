# JaRV

Welcome to **JaRV**, the definitive co-op RV survival experience where low-poly aesthetics meet high-stakes road trips. 

Traverse desolate landscapes in your customizable motorhome. Whether you are battling a blizzard, managing your "supplies," or trying to keep the chassis from falling apart after a crash, JaRV offers a unique blend of vehicular maintenance, cooperative survival, and chaotic physics.

## Key Features

* **Co-op Survival:** Team up with friends (as garden gnomes!) to navigate, defend, and maintain your mobile base.
* **Detailed Vehicle Systems:** Monitor real-time telemetry including fuel levels, oil quality, and battery life. 
* **Dynamic Damage Model:** Your RV isn't invincible. Watch it dent and deform in real-time. Keep an eye on that **RV Health** percentage.
* **Survival Essentials:** Scavenge for resources to keep the crew going—from fuel canisters to "medicinal" whiskey.
* **Defensive Combat:** Equip firearms to protect your convoy from external threats as you push through the wilderness.

## Gallery

### The Cockpit
Keep your eyes on the road and your hand on the wheel. Managing the HUD is the difference between reaching the next town and being stranded.
![Cockpit View](./screenshots/Screenshot_From_2025-12-26_19-04-31.png)

### Braving the Elements
Engage high-beams and navigate through heavy snowfall. Use chat commands to control the environment and manage server settings.
![Driving Through Snow](./screenshots/Screenshot_From_2025-12-30_23-13-54.png)

### High Stakes & Hard Knocks
The road is unforgiving. Repair your RV after heavy damage to keep the "RV Health" from hitting zero.
![Damaged RV](./screenshots/Screenshot_From_2026-01-08_21-02-13.png)

### Scavenging
Survival requires more than just gas. Explore the environment to find essential pick-ups and interactable items.
![Scavenging](./screenshots/image.png)

### Sunset Travels
Take a moment to appreciate the low-poly horizons before the night-time threats arrive.
![Sunset View](./screenshots/Screenshot_From_2026-01-02_23-45-35.png)

## Getting Started

1.  **Clone the repository:** `git clone https://github.com/nnj1/jarv.git`
2.  **Make sure blender is installed to load some models** 
3.  **Launch the game**

Executables coming soon!

### Controls
| Action Description | Key / Input |
| --- | --- |
| **Pause Game** | `Escape` |
| **Move Forward** | `W` |
| **Move Backward** | `S` |
| **Move Left** | `A` |
| **Move Right** | `D` |
| **Jump** | `Space` |
| **Handbrake** | `B` |
| **Shift Gear** | `Alt` |
| **High Beams** | `L` |
| **Horn** | `H` |
| **Interact** | `E` |
| **Shoot** | `Left Mouse Button` |
| **Zoom** | `Right Mouse Button` |
| **Reload** | `R` |
| **Toggle Flashlight** | `F` |
| **Swap Weapon Up** | `Mouse Wheel Up` |
| **Swap Weapon Down** | `Mouse Wheel Down` or `Tab` |
| **Toggle Perspective/View** | `T` |
| **Open Chat** | `Y` |
| **Console Command** | `/` (Slash) |
| **Toggle Post-Processing** | ` ` ` (Backtick) |

---

# ⌨️ Console Commands

To execute a command, open the chat box during gameplay. Commands are **case-sensitive** and must begin with a forward slash (`/`).

### **How to Use**

1. Press **`Enter`** to open the chat or **`/`** to open it with the prefix already filled.
2. Type the command (and any required arguments).
3. Press **`Enter`** to submit.

---

### 👤 General Commands

Available to all players on the server.

| Command | Arguments | Description |
| --- | --- | --- |
| `/respawn` | None | Resets your character to the current map's designated `player_spawn_point`. Useful if stuck or glitched. |

### 🚐 RV Management (Server Only)

These commands interact with the `Gmc` vehicle node to manage its resources and state.

| Command | Description |
| --- | --- |
| `/save` | Saves the RV's current position and state. |
| `/refuel` | Instantly refills the fuel tank to maximum capacity. |
| `/reoil` | Resets oil levels to 100%. |
| `/repair` | Fixes all structural and mechanical damage to the vehicle. |
| `/recharge` | Fully restores the RV's battery life. |

### 🌍 World & Environment (Server Only)

Commands to manipulate game physics, time, and scene loading.

| Command | Arguments | Description |
| --- | --- | --- |
| `/sethour` | `[0-23]` | Sets the world clock to a specific hour (e.g., `/sethour 0` for midnight). |
| `/snow` | `on` / `off` | Manually toggles the snowfall weather system. |
| `/gravity` | `on` / `off` | Toggles gravity for the host. Set to `off` to fly/noclip. |
| `/changemap` | `[name]` | Clears the current map and loads `res://scenes/maps/[name].tscn`. |
| `/advancetrack` | None | Skips the current background music track. |
| `/heal` | None | Restores the host player's health to 100%. |

### 📦 Spawning System (Server Only)

Entities are spawned relative to where the host player is currently looking.

| Command | Entity Name | Result |
| --- | --- | --- |
| `/spawn` | `bear` | Spawns a bear NPC that homes in on its spawn location. |
| `/spawn` | `skull` | Spawns a physics-based skull with a randomized scale and glow color. |
| `/spawn` | `whiskey` | Spawns a whiskey item at the end of the interaction ray. |
| `/spawn` | `soju` | Spawns a soju item at the end of the interaction ray. |
| `/spawn` | `gas_carton` | Spawns a gas carton at the end of the interaction ray. |

---
*JaRV - Survival is better on four wheels (and with a bottle of whiskey).*
