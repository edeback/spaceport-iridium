# WI-36 — Main UI Flow: Main Menu, Settings, Pause Menu

## Goal
The basic shell players expect: a Main Menu (New Game / Load Saved Game / Settings / Quit) as the entry point, a Settings screen (keybind remap, resolution, music/effects volume), and an in-game Pause Menu (New Game / Save / Load / Settings / Quit). New Game hooks a difficulty selector once WI-37 lands.

## Design
- **Scene flow.** New `ui/menus/main_menu.tscn` becomes the project's main scene; "New Game" → `change_scene_to_file("res://main.tscn")` (WI-18's deterministic bootstrap is what makes this a safe, timer-free transition). Quit-to-menu from the pause menu is the reverse. `SaveManager.load_slot`'s reload-based flow already tolerates scene swaps (its pending-load static survives); loading *from the menu* = set pending load, then enter `main.tscn` — add a `SaveManager.load_slot_from_menu(slot)` static that stages `_pending_load` without needing a live game scene.
- **Save slots.** SaveManager grows slot enumeration: `list_slots() -> Array[Dictionary]` (slot name, timestamp, cycle, credits, crew count — read from the envelope; add a small `meta` block to the envelope on save if absent). Load menu (shared scene used by main menu + pause menu): slot list with metadata, load buttons; save menu (pause only): slot list + new-slot + overwrite confirm. Quicksave slot appears in the list.
- **Settings.** `ui/menus/settings_menu.tscn`, shared by both menus. Persisted to `user://settings.cfg` (ConfigFile), applied by `Global` at startup (Global is an existing autoload — settings loading lives there; no new autoload per the two-autoload rule).
  - **Audio:** `Music`/`Effects` bus volume sliders (create the buses in the default bus layout if missing — future audio work lands into them).
  - **Resolution/display:** window mode (fullscreen/windowed) + resolution dropdown (windowed only) via `DisplayServer`/`get_window()`.
  - **Keybinds:** remap screen listing gameplay actions from the InputMap (curate: build, remove, camera, speed controls, quicksave/load, overlays…), click-to-rebind capturing the next input event, conflict warning, reset-to-defaults. Overrides saved as serialized events in settings.cfg and applied over the project defaults at startup.
- **Pause menu.** Esc in-game (when no other window claims Esc — route through UIMain's existing input arbitration): opens the menu AND sets `Global.time_manager.paused = true` (restoring the *prior* pause state on close — don't unpause a game the player had paused manually). Buttons: Resume, Save, Load, Settings, New Game (confirm), Quit to Menu (confirm + "unsaved progress" note), Quit to Desktop (confirm).
- **Game over screen** gains "Quit to Menu" alongside its existing options.

## Files to touch
- **New:** `ui/menus/main_menu.tscn/.gd`, `settings_menu.tscn/.gd`, `save_load_menu.tscn/.gd`, `pause_menu.tscn/.gd`, `keybind_row.gd`
- `project.godot` — main scene → main_menu; audio bus layout; any new input actions
- `scripts/managers/save_manager.gd` — `list_slots`, envelope meta block, `load_slot_from_menu`
- `scripts/managers/global.gd` — settings load/apply/save helpers
- `ui/ui_main.gd` — Esc arbitration hook for the pause menu
- `ui/game_over_screen.gd` — quit-to-menu
- WI-37 hook: difficulty selector container in the New Game path (hidden until WI-37)

## Implementation order
1. Main menu scene + New Game/Quit + project main-scene switch (WI-18 must be done).
2. Slot metadata + list + Load from menu.
3. Pause menu (pause semantics, Save/Load, quit paths).
4. Settings: audio → display → keybinds (keybinds are the bulk).
5. Game-over hook + polish (menu music slot, version label).

## Edge cases
- Esc pressed with a build preview / open window active: existing UI claims it (cancel preview first); pause menu only on "nothing else wants Esc" — arbitrate in one place.
- Load from pause menu of a *different* slot: full scene reload flow — confirm dialog since current progress drops.
- Rebinding to a key already bound: warn + allow swap or cancel; never leave an action with zero bindings; mouse-button and gamepad events capturable or explicitly excluded (v1: keyboard+mouse only).
- Rebinding the pause key itself, then Esc-in-remap: remap capture consumes the event — dedicated cancel button in the capture dialog.
- settings.cfg corrupt/missing: fall back to defaults silently, rewrite on next save.
- Fullscreen→windowed on a resolution larger than the screen: clamp to usable screen size.
- Save while an event card / raid banner is open: allowed (state saves via managers) — verify card queue restores (EventManager already saves pending events).
- New Game from pause when a run is active: confirm; then `change_scene_to_file(main.tscn)` with pending-load cleared.
- Two rapid Esc presses (open+close same frame): guard with the menu's visibility state; pause counter restores correctly.

## Verification
1. Boot → main menu (no game sim running behind it); New Game → clean start; Quit works.
2. Play, quicksave, quit to menu, Load Saved Game → exact game restored; slot list shows correct metadata for multiple slots; overwrite confirm works.
3. Pause menu: opens paused, Resume restores prior speed AND prior manual-pause state; Save→Load round-trip from within a session.
4. Settings: volume sliders audibly change buses and persist across restart; resolution/window mode applies and persists; rebind the build key → new key works in-game, persists, reset-to-defaults restores.
5. Game over → Quit to Menu → New Game works without residue (managers fresh — the WI-18 bootstrap regression).
6. Esc arbitration: preview open → Esc cancels preview, second Esc opens menu; trade screen open → Esc closes it first.
