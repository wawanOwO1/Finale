# CLAUDE.md — FINALE

Game jam deckbuilder, Godot 4.7 project in `godot/` (the old Vite/TS version in `src/` is reference only).
Design docs: `GDD.md`, `ART_DIRECTION.md`, `GRAND_DESIGN.md` (Indonesian). In-game text is English.

## Workflow: always merge into main when an implementation is done

The user keeps the Godot editor open on the **main checkout** (`P:\PROJECT\OpenGameJam\godot`, branch `main`).
Sessions usually run in a git worktree under `.claude/worktrees/…`, which the editor never sees.
So when a piece of implementation is finished and its tests pass:

1. Commit on the worktree branch.
2. Merge that branch into `main` **in the main checkout** (`git -C P:/PROJECT/OpenGameJam merge <branch>`).
   - First check `git -C P:/PROJECT/OpenGameJam status`. Editor noise (e.g. reordered `project.godot`,
     generated `.uid` files) is fine to leave alone if the merge does not touch those files.
   - Any other uncommitted work there is the user's: stop and ask before merging over it.
   - On conflicts, resolve them in the worktree first (merge `main` into the branch), then merge again.
3. Tell the user to save/close open scenes in the editor before the merge lands if they may have unsaved edits.

Do not push unless asked.

## Godot conventions

- New systems are **nodes in scenes**, not spawned from code: system nodes in `scenes/main.tscn`
  (wired in `main.gd`), HUD pieces as unique-named nodes in `scenes/ui/duel_ui.tscn` (read via `%Name`).
  Tunable values are `@export` so they show in the Inspector.
- `scripts/core/` is pure logic (no nodes); visuals listen to `Duel` signals.
- Godot binary: `H:\Godot_v4.7.2-stable_win64_console.exe`. After adding a `class_name` script, run
  `--headless --path godot --import` first so the class cache knows it.
- Tests: `tests/sim.gd` (headless), `tests/audio_check.gd` (headless), `tests/fx_check.gd` (headless), `tests/glb_check.gd` (headless),
  `tests/ui_drive.gd`, `tests/chef_drive.gd`, `tests/fx_drive.gd` and
  `tests/hit_probe.gd` (need a window). See `godot/README.md`.
