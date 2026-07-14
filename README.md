# DecursiveLite

> ⚠️ **Note:** This addon is currently in **Beta**. We are actively testing and refining the code prior to the official release. Please report any bugs or feedback!

A lightweight, highly optimized decurse grid built specifically for the **Project Ascension (Classless WoW)** client, featuring full **Bleed** dispel support and class-colored visual alerts.

---

## 🛠️ Supported Classes & Dispel Spells

DecursiveLite scans your spellbook dynamically. It automatically detects and binds the best dispel spell for your active class build.

| Dispel Type | Dynamic Click | Supported Ascension Spells & Archetypes |
| :--- | :--- | :--- |
| **Poison** | **Left-Click** | *Sanctify* (Sun Cleric), *Elune's Purification* (Starcaller), *Antivenom* (Venomancer), *Cure Poison* |
| **Curse** | **Right-Click** | *Hexbreak* (Witch Doctor), *Blight Antidote* (Venomancer), *Devour Curse* (Cultist), *Remove Curse* |
| **Magic** | **Left-Click** | *Sanctify* (Sun Cleric), *Burn Impurities* (Pyromancer), *Devour Magic* (Cultist), *Dispel Magic*, *Cleanse* |
| **Disease** | **Right-Click** | *Sanctify* (Sun Cleric), *Elune's Purification* (Starcaller), *Burn Impurities* (Pyromancer), *Cure Disease*, *Purify* |
| **Bleed** | **Right-Click** | *Cauterize* (Pyromancer Talent) |

---

## 💻 Slash Commands

You can configure the addon layout instantly in-game using the `/dl` or `/decursivelite` slash commands.

| Command | Action Description |
| :--- | :--- |
| `/dl unlock` | Reveals the gray drag handle directly above the first button. |
| `/dl lock` | Locks the frame in place and hides the dragging handle. |
| `/dl reset` | Instantly snaps the grid container back to the center of your screen. |
| `/dl test` | Toggles simulated debuffs and triggers the custom **AfflictionAlert** warning sound. |

> 💡 **How to move the grid:** Write `/dl unlock` in chat, then hold down **Shift** while dragging the tiny gray square above the first player button.

---

## ⚙️ In-Game Options Menu

Rather not use chat commands? You can access all configurations by pressing **Esc > Interface > AddOns > DecursiveLite**. 

This panel features interactive buttons for locking, resetting, and testing your layout.