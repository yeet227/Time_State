# Time_State: Chrono-Wasteland

A 3D open-world dieselpunk wasteland RPG built in **Godot Engine 3.5**. Explore a vast fractured continent where temporal weapons ruptured causality during the "Time Wars". Traverse distinct biomes, drive wasteland interceptors across rugged dunes, wield an arsenal of melee weapons and energy firearms, manipulate time with Chrono Dilation, and uncover faction strongholds.

---

## 🎮 Key Features (Avenue 4: Dieselpunk Chrono-Wasteland)

* **🚗 Drivable Wasteland Cruiser:**
  - Full arcade vehicle physics with terrain slope alignment, drift handbrake, and Nitro Chrono-Boost (`Shift`).
  - Seamless enter/exit system (`[E]`) with chase camera transfer.
  - High-speed ramming physics that crush and launch hostile mobs.
  - Dual headlights for nighttime wasteland navigation.

* **⚔️ Multi-Weapon Arsenal & Melee Combat:**
  - **Energy Blaster (`1`):** Ranged energy projectile sidearm consuming Energy Ammo.
  - **Wasteland Sword (`2`):** Fast steel slashing blade for agile close-quarters strikes.
  - **Scrapper Battleaxe (`3`):** Heavy cleaving weapon with high knockback and crushing damage.
  - Hotkey swapping (`1`, `2`, `3`) or mouse wheel cycling with animated weapon models.

* **⏳ Chrono Dilation (Bullet Time):**
  - Toggle with `[Q]` to warp world time to **0.32x speed** while maintaining player mobility and aim responsiveness.
  - Screen border temporal distortion vignette and slow-mo HUD indicator.

* **🏛️ Faction Landmarks & Discovery System:**
  - **Scrapper Outpost & Garage:** Scrappers Coalition territory with starter supplies and vehicle garage.
  - **The Imperial Citadel:** Ancient Dynasty palace fortified with elite Chrono Drones and high-tier vault chests.
  - **Sanctuary of the Church:** The Faithful Order's temple holding the Golden Pillow Relic.
  - **Tank Graveyard & Siren Outpost:** Iron Legion remnants guarded by Heavy Automatons.
  - Dynamic discovery banners announce new landmarks as you traverse the world.

* **👾 Diverse Enemy Archetypes:**
  - **Wasteland Raiders:** Standard ground sentries with ranged blasters and melee attacks.
  - **Bouncing Gremlins:** Fast leaping swarmers utilizing custom 3D models with aggressive claw attacks.
  - **Floating Chrono Drones:** Hovering aerial snipers that bob above the terrain and fire energy lasers.
  - **Heavy Automatons:** Armored tank minibosses guarding faction vaults.

* **📦 Survival & Persistence:**
  - Inventory and interactive storage chests with transfer modals (`[I]` or `[Tab]`).
  - Health & stamina progression, consumable medkits, tonics, and permanent Time Shard / Chrono Speed Core stat multipliers.
  - Quick Save (`[F5]`) and Quick Load (`[F9]`) with persistent JSON storage.

---

## ⌨️ Controls & Keybindings

### On Foot
| Action | Default Key | Description |
| :--- | :--- | :--- |
| **Move & Strafe** | `W` / `A` / `S` / `D` | Character movement |
| **Sprint** | `Shift` | High-speed sprint (consumes stamina) |
| **Jump** | `Space` | Jump (or ascend in flight mode) |
| **Weapon Swap** | `1`, `2`, `3` | 1: Blaster \| 2: Sword \| 3: Battleaxe |
| **Cycle Weapon** | `Mouse Wheel Up/Down` | Cycle through equipped weapons |
| **Attack / Shoot** | `Left Click` | Attack with active weapon |
| **Bullet Time** | `Q` | Toggle Chrono Dilation (0.32x slow-motion) |
| **Interact / Drive** | `E` | Drive Cruiser / Open Chest / Loot |
| **Inventory** | `I` or `Tab` | Open Inventory & Storage Chest modal |
| **Flight Mode** | `V` | Quick toggle debug flight |
| **Cheat Menu** | `F1` | Open sandbox cheats & multipliers |
| **Quick Save / Load** | `F5` / `F9` | Save / Load persistent game state |
| **Pause / Settings** | `Esc` | Pause menu, audio, FOV, sensitivity |

### In Vehicle (Wasteland Cruiser)
| Action | Key | Description |
| :--- | :--- | :--- |
| **Throttle / Reverse** | `W` / `S` | Accelerate forward / reverse |
| **Steering** | `A` / `D` | Steer wheels left / right |
| **Handbrake / Drift** | `Space` | Engage drift brakes |
| **Nitro Chrono-Boost** | `Shift` | High-speed turbo boost |
| **Upright Vehicle** | `R` | Reset cruiser if flipped upside-down |
| **Exit Vehicle** | `E` | Dismount beside vehicle |

---

## 🛠️ Setup & Running

* **Engine:** Godot Engine 3.5.x (Standard Version).
* **Setup:**
  1. Clone this repository:
     ```bash
     git clone https://github.com/yeet227/Time_State.git
     ```
  2. Open Godot, click **Import**, select `project.godot` inside the project folder, and press **Edit**.
  3. Press **F5** (or the Play button) to launch the game.