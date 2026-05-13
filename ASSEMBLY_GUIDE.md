# AlgoQuest — Complete Assembly & Resources Guide
# How to combine all 6 game parts into one working Godot 4 project

================================================================
PART 1 — WHAT YOU NEED (RESOURCES CHECKLIST)
================================================================

FROM YOUR ORIGINAL algoquest_lpc.zip:
  □ assets/codemon/font/freepixel.ttf
  □ assets/codemon/audio/music/*.ogg  (6 files)
  □ assets/codemon/audio/sfx/*.ogg    (7 files)

ALREADY IN THIS PROJECT:
  ✓ CGabrielChars24x24.png    (character sprites)
  ✓ CGabrielFaces48x48.png    (face sprites)
  ✓ intro.ogv                 (main menu video)
  ✓ All 5 chapter scripts     (v2/v3 fixed versions)
  ✓ All autoloads             (7 singletons)
  ✓ All scene files           (7 .tscn files)
  ✓ WorldMap + MainMenu       (full UI)

================================================================
PART 2 — STEP BY STEP ASSEMBLY
================================================================

STEP 1 — Open Project
─────────────────────
1. Install Godot 4.2+ from https://godotengine.org
2. Open Godot → Import → select AlgoQuest/project.godot
3. Wait for asset import (≈30 seconds first time)
   Godot will show warnings about missing audio/font — ignore for now

STEP 2 — Copy Font
──────────────────
From your algoquest_lpc folder:
  COPY:  assets/codemon/font/freepixel.ttf
  TO:    AlgoQuest/assets/fonts/freepixel.ttf

STEP 3 — Copy Audio Files
──────────────────────────
Create folders if they don't exist:
  AlgoQuest/assets/audio/bgm/
  AlgoQuest/assets/audio/sfx/

COPY MUSIC (rename as shown):
  street_laboratory.ogg  →  bgm/main_theme.ogg
  street_laboratory.ogg  →  bgm/street_laboratory.ogg  (copy twice)
  mountain.ogg           →  bgm/mountain.ogg
  desert.ogg             →  bgm/desert.ogg
  forest.ogg             →  bgm/forest.ogg
  beach.ogg              →  bgm/beach.ogg

COPY SFX:
  success.ogg            →  sfx/success.ogg
  fail.ogg               →  sfx/fail.ogg
  bubble.ogg             →  sfx/bubble.ogg
  jump_1.ogg             →  sfx/jump_1.ogg
  jump_2.ogg             →  sfx/jump_2.ogg

  NOTE: level_up.ogg and button.ogg may not exist in original pack.
  If missing, just copy success.ogg and rename it — game won't crash.

STEP 4 — Verify Autoloads
──────────────────────────
Project → Project Settings → Autoload tab
Should show ALL 7 in this order:
  1. DifficultyManager   res://scripts/autoload/DifficultyManager.gd
  2. SaveManager         res://scripts/autoload/SaveManager.gd
  3. ProgressTracker     res://scripts/autoload/ProgressTracker.gd
  4. AdaptiveDifficulty  res://scripts/autoload/AdaptiveDifficulty.gd
  5. AudioManager        res://scenes/AudioManager.tscn
  6. GameRouter          res://scripts/autoload/GameRouter.gd
  7. SpriteHelper        res://scripts/shared/SpriteHelper.gd

If any are missing, click + and add them manually.

STEP 5 — Run the Game
──────────────────────
Press F5.
Main scene is: scenes/main_menu/MainMenu.tscn

You should see:
  • Intro video playing as background
  • "AlgoQuest" title animating in
  • Characters walking across the bottom
  • Start / Credits / Quit buttons

================================================================
PART 3 — HOW THE 6 GAME PARTS FIT TOGETHER
================================================================

GAME FLOW:
  MainMenu.tscn
      ↓ Start button
  WorldMap.tscn
      ↓ Click chapter node
  Chapter scene (1–5)
      ↓ Complete or fail
  ChapterCompleteScreen.tscn (overlay)
      ↓ Next / Retry / Map button
  WorldMap.tscn or next chapter

AUTOLOAD DEPENDENCY CHAIN:
  DifficultyManager  ← read by all 5 chapter scripts
       ↓
  SaveManager        ← stores scores, stars, unlocks
       ↓
  ProgressTracker    ← logs actions → SaveManager → Firebase
       ↓
  AdaptiveDifficulty ← reads ProgressTracker → adjusts DifficultyManager
       ↓
  GameRouter         ← uses all above to route between scenes
       ↓
  SpriteHelper       ← maps CGabriel sheet to game character roles

CHAPTER SCRIPTS (what each file does):
  QueueGame.gd      ← FIFO queue: service types, VIP events, lanes
  StackGame.gd      ← LIFO stack: push/pop, sequence goals, task cards
  LinkedListGame.gd ← Linked list: connect, insert, delete, reverse, cycle
  TreeGame.gd       ← BST: place numbers, balance check, traversal animation
  GraphGame.gd      ← Graph: connect, BFS, Dijkstra shortest path

================================================================
PART 4 — ADJUSTING DIFFICULTY
================================================================

The difficulty system is already wired. To change default starting tier:

  In DifficultyManager.gd, line 3:
    var current_tier: int = 0    ← change 0 to 1/2/3/4 for Easy/Normal/Hard/Expert

Players can also change it from the WorldMap difficulty buttons (B/E/N/H/X).

Adaptive difficulty runs automatically:
  • Player fails 2+ times with accuracy < 50% → tier drops 1
  • Player gets S/A grade 3 times in a row → tier raises 1

To disable adaptive difficulty, remove AdaptiveDifficulty from Autoloads.

================================================================
PART 5 — ADDING FIREBASE (THESIS ANALYTICS)
================================================================

1. Create Firebase project at https://console.firebase.google.com
2. Enable Realtime Database
3. Get your database URL: https://your-project-default-rtdb.firebaseio.com

4. Open scripts/autoload/SaveManager.gd
5. Find _push_to_firebase() (near bottom) and implement:

func _push_to_firebase() -> void:
    var http := HTTPRequest.new()
    add_child(http)
    var url := "https://YOUR-PROJECT.firebaseio.com/saves/%s.json" % \
        _data.get("player_name","anon")
    var headers := ["Content-Type: application/json"]
    http.request(url, headers, HTTPClient.METHOD_PUT, JSON.stringify(_data))

6. For action logs in push_action_log():

func push_action_log(chapter: String, action: String, payload: Dictionary) -> void:
    var http := HTTPRequest.new()
    add_child(http)
    var timestamp := str(Time.get_ticks_msec())
    var url := "https://YOUR-PROJECT.firebaseio.com/logs/%s/%s/%s.json" % \
        [_data.get("player_name","anon"), chapter, timestamp]
    var headers := ["Content-Type: application/json"]
    var body := {"action": action, "data": payload}
    http.request(url, headers, HTTPClient.METHOD_PUT, JSON.stringify(body))

================================================================
PART 6 — ADDING YOUR PLAYER NAME / LOGIN SCREEN
================================================================

Before WorldMap, you can show a name entry screen:

1. Create scenes/ui/NameEntry.tscn:
   Node2D
   ├── Label    "Enter your name:"
   ├── LineEdit (name: NameInput)
   └── Button   "Start" → calls:
       SaveManager.set_player_name($NameInput.text)
       GameRouter.go_to_world_map()

2. Change GameRouter.go_to_main_menu() to go to NameEntry first, or
   add it to MainMenu before going to WorldMap.

================================================================
PART 7 — SCENE FILE LOCATIONS
================================================================

scenes/
├── main_menu/
│   └── MainMenu.tscn           ← Start here (set as main scene)
├── world_map/
│   └── WorldMap.tscn           ← Chapter select
├── chapters/
│   ├── queue/QueueGame.tscn
│   ├── stack/StackGame.tscn
│   ├── linked_list/LinkedListGame.tscn
│   ├── tree/TreeGame.tscn
│   └── graph/GraphGame.tscn
├── ui/
│   ├── ChapterCompleteScreen.tscn
│   └── PauseMenu.tscn
└── AudioManager.tscn           ← Autoload scene (BGM + SFX players)

================================================================
PART 8 — COMMON ERRORS AND FIXES
================================================================

ERROR: "AudioManager not found"
  FIX: Project → Autoloads → verify AudioManager points to
       res://scenes/AudioManager.tscn (not the .gd file)

ERROR: "freepixel.ttf not found" (warning only, not crash)
  FIX: Copy freepixel.ttf to assets/fonts/ as described in Step 2

ERROR: "intro.ogv failed to load"
  FIX: The video file must be Ogg Theora format.
       Your uploaded file is already correct Theora format.
       If it still fails, convert with: ffmpeg -i input.mp4 -c:v libtheora output.ogv

ERROR: Chapter shows empty screen / no sprites
  FIX: The CGabriel sprite sheet is loaded by SpriteHelper.
       Make sure CGabrielChars24x24.png is in assets/sprites/characters/
       and SpriteHelper is registered in Autoloads.

ERROR: "GameRouter.retry_chapter not found"
  FIX: GameRouter.gd may be missing retry_chapter(). Open it and
       verify the function exists. It calls the chapter scene by id.

ERROR: Save file corrupt / game resets
  FIX: Delete user://algoquest_save.json to reset all progress.
       Location: %APPDATA%\Godot\app_userdata\AlgoQuest\ (Windows)

================================================================
PART 9 — ADDING PAUSE MENU TO EACH CHAPTER
================================================================

Each chapter scene needs a PauseMenu CanvasLayer child.
Either:
  A) Add manually in Godot editor:
     1. Open QueueGame.tscn in editor
     2. Add child: CanvasLayer → name it "PauseMenu"
     3. Attach script: res://scripts/ui/PauseMenu.gd
     4. Add Overlay (ColorRect, full screen, black semi-transparent)
        and build the VBox hierarchy per PauseMenu.gd comment block

  B) Or use Godot's "Instantiate Child Scene":
     1. Right-click root in scene tree → Instantiate Child Scene
     2. Select scenes/ui/PauseMenu.tscn

Then in each chapter script _unhandled_input(), add at the top:
  if event.is_action_pressed("ui_cancel"):
      $PauseMenu.toggle()
      return

================================================================
PART 10 — THESIS DEFENSE TALKING POINTS
================================================================

DSA CONCEPTS TAUGHT:
  Queue:    FIFO, service ordering, patience systems, lane routing
  Stack:    LIFO, push/pop discipline, sequence planning
  List:     Pointer traversal, head/tail/null, cycle detection
  BST:      Left < parent < right, inorder traversal = sorted output
  Graph:    BFS frontier expansion, Dijkstra minimum cost path

EACH WRONG ACTION EXPLAINS THE CONCEPT:
  Queue:   "FIFO: First In, First Out. Serve front of line first."
  Stack:   "LIFO: Only the TOP rune is accessible."
  List:    "Each node can have only ONE incoming pointer."
  Tree:    "Left child must be < parent. (BST Rule violated)"
  Graph:   "BFS visits nearest nodes first. Expected city B, not D."

ANALYTICS FOR THESIS:
  • _correct_count and typed mistake counts in every chapter
  • ProgressTracker.log_action() called on every player action
  • ProgressTracker.complete_chapter() called with full stats
  • SaveManager stores last 10 attempt history per chapter
  • Accuracy %, dominant mistake shown on ChapterCompleteScreen
  • Grade S/A/B/C/F system with star rating (1–3 stars)
  • Adaptive difficulty adjusts tier based on performance history
