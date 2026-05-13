# AlgoQuest — Project Setup Guide

## What's in this package

```
AlgoQuest/
├── project.godot                  ← Open this in Godot 4
├── audio_bus_layout.tres          ← Music + SFX audio buses
│
├── assets/
│   ├── video/
│   │   └── intro.ogv              ← Your Theora intro video (main menu background)
│   ├── sprites/characters/
│   │   ├── CGabrielChars24x24.png ← RPG character sprite sheet (10 cols × 24px)
│   │   └── CGabrielFaces48x48.png ← Face sprites for UI
│   ├── fonts/
│   │   └── README.txt             ← Copy freepixel.ttf here
│   └── audio/
│       └── README.txt             ← Copy audio files here
│
├── scenes/
│   ├── main_menu/MainMenu.tscn    ← Video BG + character parade + menu
│   ├── world_map/WorldMap.tscn    ← Chapter select + unlock system
│   ├── chapters/
│   │   ├── queue/QueueGame.tscn
│   │   ├── stack/StackGame.tscn
│   │   ├── linked_list/LinkedListGame.tscn
│   │   ├── tree/TreeGame.tscn
│   │   └── graph/GraphGame.tscn
│   └── ui/
│       ├── ChapterCompleteScreen.tscn
│       └── PauseMenu.tscn
│
└── scripts/
    ├── autoload/                  ← All 7 autoloads (see Step 1)
    ├── chapters/                  ← All 5 chapter game scripts (v2/v3)
    ├── main_menu/MainMenu.gd
    ├── world_map/WorldMap.gd
    ├── shared/SpriteHelper.gd     ← CGabriel sprite sheet helper
    └── ui/
        ├── ChapterCompleteScreen.gd
        └── PauseMenu.gd
```

---

## Step 1 — Open in Godot 4

1. Download and install **Godot 4.2+** from https://godotengine.org
2. Open Godot → **Import** → select this folder's `project.godot`
3. Let Godot import all assets (first open takes ~30 seconds)

---

## Step 2 — Copy Missing Assets from Original LPC Project

### Font
```
FROM: algoquest_lpc/assets/codemon/font/freepixel.ttf
TO:   AlgoQuest/assets/fonts/freepixel.ttf
```

### Audio (copy the whole folder contents)
```
FROM: algoquest_lpc/assets/codemon/audio/music/*.ogg
TO:   AlgoQuest/assets/audio/bgm/

FROM: algoquest_lpc/assets/codemon/audio/sfx/*.ogg
TO:   AlgoQuest/assets/audio/sfx/
```

**Rename mapping** (old LPC name → new path):
| Old name | New path |
|----------|----------|
| `street_laboratory.ogg` | `bgm/main_theme.ogg` AND `bgm/street_laboratory.ogg` |
| `mountain.ogg` | `bgm/mountain.ogg` |
| `desert.ogg` | `bgm/desert.ogg` |
| `forest.ogg` | `bgm/forest.ogg` |
| `beach.ogg` | `bgm/beach.ogg` |
| `success.ogg` | `sfx/success.ogg` |
| `fail.ogg` | `sfx/fail.ogg` |
| `bubble.ogg` | `sfx/bubble.ogg` |
| `jump_1.ogg` | `sfx/jump_1.ogg` |
| `jump_2.ogg` | `sfx/jump_2.ogg` |

> **The game runs without audio** — all AudioManager calls check `ResourceLoader.exists()` first.

---

## Step 3 — Verify Autoloads

Godot reads autoloads from `project.godot`. They should already be registered.
To verify: **Project → Project Settings → Autoload tab**

Required order:
| Name | Path |
|------|------|
| DifficultyManager | `res://scripts/autoload/DifficultyManager.gd` |
| SaveManager | `res://scripts/autoload/SaveManager.gd` |
| ProgressTracker | `res://scripts/autoload/ProgressTracker.gd` |
| AdaptiveDifficulty | `res://scripts/autoload/AdaptiveDifficulty.gd` |
| AudioManager | `res://scenes/AudioManager.tscn` |
| GameRouter | `res://scripts/autoload/GameRouter.gd` |
| SpriteHelper | `res://scripts/shared/SpriteHelper.gd` |

---

## Step 4 — Run the Game

Press **F5** or click the ▶ Play button.

The main menu will:
- Play `assets/video/intro.ogv` as the full-screen background
- Animate 12 RPG characters walking across the bottom
- Show title, subtitle, and Start / Credits / Quit buttons

---

## How the Sprite Sheet Works

**CGabrielChars24x24.png** — 240×3816 px
- 10 frames × 24px wide per row
- Each character = 3 rows (facing down / up / right)
- Frame order: Walk1, Stand, Walk2, Punch1-3, Cast1-4

**SpriteHelper** autoload maps roles to sheet regions:
```gdscript
# Get a standing texture for any character
var tex := SpriteHelper.get_stand_texture("m_warrior")

# Setup a Sprite2D directly
SpriteHelper.setup_sprite(my_sprite, "merchant", 0)  # direction 0=down

# Use in chapter scripts instead of the old codemon sprites
```

**Queue chapter** — citizens use: `m_warrior`, `merchant`, `m_healer`, `king`  
**Stack chapter** — runes use: `fire_elemental`, `water_elemental`, etc.  
**Linked List**  — nodes use: `m_ninja`, `f_ninja`, `pirate`, `bard`, etc.  
**Tree chapter** — nodes use: `m_magician`, `vampire`, `m_dark_knight`, etc.  
**Graph chapter** — cities use: `m_soldier`, `captain`, `m_samurai`, etc.

---

## What Changed vs Original LPC Project

### New Files
| File | Purpose |
|------|---------|
| `SpriteHelper.gd` | Maps CGabriel sheet to game roles |
| `MainMenu.gd/.tscn` | Video background + character parade |
| `WorldMap.gd/.tscn` | Chapter select + stars + unlock system |
| `SaveManager.gd` | JSON save, Firebase stub |
| `ProgressTracker.gd` | Per-action analytics logging |
| `AdaptiveDifficulty.gd` | Auto tier adjust on repeat fails/wins |
| `ChapterCompleteScreen.gd` | Grade, stars, DSA recap, retry/next |
| `PauseMenu.gd` | ESC pause, restart, volume, how-to |

### Upgraded Chapter Scripts
| Chapter | Version | Key fixes |
|---------|---------|-----------|
| Queue | v2 | Service types, VIP events, lane routing, tutorial |
| Stack | v2 | Sequence goals, mixed ops task cards, crown indicator |
| Linked List | v3 | Structural validation, magnetic snap, cycle animation |
| BST Tree | v2 | Balance enforced, branch animation, inorder traversal |
| Graph | v2 | BFS queue display, Dijkstra multi-hop, all 7 v1 bugs fixed |

---

## Firebase Integration

Open `SaveManager.gd` and implement these two stub methods:

```gdscript
func _push_to_firebase() -> void:
    # POST to: https://your-project.firebaseio.com/players/{uid}/save.json
    # Body: JSON.stringify(_data)
    var http := HTTPRequest.new()
    add_child(http)
    http.request(YOUR_FIREBASE_URL, [...headers], HTTPClient.METHOD_POST,
        JSON.stringify(_data))

func push_action_log(chapter: String, action: String, payload: Dictionary) -> void:
    # POST individual action for real-time analytics
    pass
```

---

## Difficulty System

Set tier from WorldMap difficulty buttons or anywhere in code:
```gdscript
DifficultyManager.set_tier(0)  # 0=Beginner 1=Easy 2=Normal 3=Hard 4=Expert
```

**Adaptive difficulty** runs automatically before each chapter load.
After 2+ failed attempts with accuracy < 50% → tier drops 1.
After 3 S/A grades in a row → tier raises 1.

---

## Save File Location

`user://algoquest_save.json`

- Windows: `%APPDATA%\Godot\app_userdata\AlgoQuest\`
- Linux: `~/.local/share/godot/app_userdata/AlgoQuest/`
- macOS: `~/Library/Application Support/Godot/app_userdata/AlgoQuest/`
