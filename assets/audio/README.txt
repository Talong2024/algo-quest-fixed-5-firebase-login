AUDIO FILES REQUIRED
====================
Copy audio files from your original AlgoQuest LPC project:

FROM: assets/codemon/audio/
TO:   assets/audio/

Expected structure:
  assets/audio/bgm/main_theme.ogg
  assets/audio/bgm/street_laboratory.ogg
  assets/audio/bgm/mountain.ogg
  assets/audio/bgm/desert.ogg
  assets/audio/bgm/forest.ogg
  assets/audio/bgm/beach.ogg

  assets/audio/sfx/success.ogg
  assets/audio/sfx/fail.ogg
  assets/audio/sfx/button.ogg
  assets/audio/sfx/bubble.ogg
  assets/audio/sfx/jump_1.ogg
  assets/audio/sfx/jump_2.ogg
  assets/audio/sfx/level_up.ogg

All AudioManager calls are guarded with ResourceLoader.exists() checks —
the game runs silently without audio, no crash.
