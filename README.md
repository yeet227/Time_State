# Time_State

A 3D open-world prototype built in **Godot Engine 3.5**. Explore a dynamic environment featuring real-time day/night cycles, stamina-driven movement, and interactive NPC behaviors.

---

## 🎮 Features
- **Player Mechanics:** Smooth 3D third-person/first-person controls, jumping, and stamina-regulated sprinting.
- **Dynamic Time System:** Rotating sun system simulating day/night illumination cycles.
- **AI & NPCs:** Basic pathing and target acquisition for non-player characters.
- **In-Game Utilities:** Debug FPS counter and UI menus.

---

## 🛠️ Requirements & Getting Started
* **Engine:** Godot Engine 3.5.x (Standard Version).
* **Setup:**
  1. Clone this repository or download the ZIP:
     ```bash
     git clone [https://github.com/yeet227/Time_State.git](https://github.com/yeet227/Time_State.git)
     ```
  2. Open Godot, click **Import**, select `project.godot` inside the project folder, and press **Edit**.
  3. Press **F5** (or the Play button) to launch the main scene.

---

## ⌨️ Controls
Configure in `Project Settings > Input Map`:

| Action | Default Key | Description |
| :--- | :--- | :--- |
| `move_forward` | `W` / `Up Arrow` | Move forward |
| `move_backward` | `S` / `Down Arrow` | Move backward |
| `move_left` | `A` / `Left Arrow` | Move left |
| `move_right` | `D` / `Right Arrow` | Move right |
| `jump` | `Space` | Jump |
| `Stamina` | `Shift` | Sprint (consumes stamina) |
| `toggle_fps` | `F3` | Toggle FPS display |

---

## 📋 Roadmap
- [ ] On-screen HUD for Stamina and Health bars.
- [ ] NPC state machine (Patrol, Alert, Chase, Return).
- [ ] Environment lighting curves synced with the sun cycle.
- [ ] Transition/migration to Godot 4.x.