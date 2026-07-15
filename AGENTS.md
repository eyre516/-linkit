<!-- From: D:/A项目/连连看/AGENTS.md -->
# AGENTS.md — Project Guide for AI Coding Agents

## Project Overview

This is a small **Godot 4** game project named **连连看** (Liánliánkàn). The implemented gameplay is a classic tile-matching game on a **7×12 grid** (84 tiles, 42 pairs). Players click two matching tiles; if they can be connected with at most **2 turns** via empty paths (including the virtual outer border), the pair is eliminated. The game detects victory when all pairs are cleared, auto-shuffles remaining tiles when no valid matches remain, and supports undo/redo moves.

- **Engine:** Godot 4.5
- **Primary Language:** GDScript
- **Renderer:** GL Compatibility
- **Platform:** Desktop / mobile (Godot export templates required)

## Project Structure

```
.
├── project.godot          # Godot project configuration
├── game.gd                # Main game logic (GDScript)
├── game.tscn              # Main scene (UI + grid + buttons)
├── cell.gd                # Cell component logic
├── cell.tscn              # Cell component scene
├── icon.svg / icon.png    # Project icons
├── assets/
│   ├── pokemon/
│   │   └── normal/        # 42 Pokemon tile icons (256×256, optimized PNG)
│   ├── classicPics/
│   │   └── level3/normal/ # 42 classic tile icons (39×39 PNG)
│   └── sound/             # Sound effects and background music (MP3)
├── .editorconfig          # EditorConfig (UTF-8 only)
├── .gitattributes         # Normalize line endings to LF
└── .gitignore             # Ignore .godot/ and /android/
```

## Technology Stack

- **Godot 4.5** with `config_version=5`
- **GDScript** for all game logic
- **GL Compatibility** rendering backend
- **.NET assembly name** configured (`连连看`) but no C# source files present
- Node-based scene system using `Control`, `GridContainer`, `PanelContainer`, `Button`, `Label`, `TileMapLayer`

## Build and Run Commands

Godot projects do not require a compile step for GDScript.

### Run in Editor

Open the project folder in **Godot Editor 4.5+** and press `F6` (run current scene) or `F5` (run main scene).

### Run from CLI

```bash
# Run the project from the command line
godot --path .

# Run the main scene directly
godot --path . --scene game.tscn
```

### Export

Use Godot's export presets (`Project > Export`) to build for Windows, macOS, Linux, Web, Android, or iOS. Export templates must be installed first.

## Code Organization

### `game.gd`

Main game controller attached to `game.tscn`. Responsibilities:

- Tracks `GameState` (`PLAYING`, `GAME_OVER`)
- Maintains the 7×12 `board` array
- Tracks `selected_index` for the first clicked tile
- Implements move history with `move_history` and `undo_history` stacks for undo/redo
- Handles cell click events, tile elimination, win/draw detection, and dead-end shuffle
- Updates UI button states and game-over label

Key constants:

- `ROWS := 7`, `COLS := 12`, `PAIRS := 42`
- `DIRECTIONS` for 4-direction pathfinding

### `cell.gd`

Reusable cell component attached to `cell.tscn`. Responsibilities:

- Emits `cell_clicked(index: int)` when left-clicked
- Displays the appropriate icon based on `tile_type` (0 = empty)
- Uses `class_name Cell` for typed references
- Preloads tile textures from `res://assets/pokemon/normal/` or `res://assets/classicPics/level3/normal/` depending on the active skin

### Scenes

- `game.tscn` — root scene with a `TileMapLayer` background, button bar (`Undo`, `Redo`, `Restart`), a `GridContainer` holding 84 `Cell` instances, and a game-over overlay.
- `cell.tscn` — panel-based cell with a `TextureRect` for icons.

## Code Style Guidelines

- Use **GDScript** and Godot 4 conventions (`@onready`, typed variables, signals, `class_name`).
- Node references use the `%UniqueName` syntax where applicable (`%UndoButton`, `%RedoButton`, `%GridContainer`, `%GameOverLabel`).
- Code comments are mixed **Chinese and English**. When modifying, match the surrounding comment language if possible.
- Prefer typed collections (`Array[Dictionary]`) and explicit types in function signatures.

## Testing Instructions

There are currently **no automated tests** in this project.

### Manual Testing Checklist

1. Launch the project and verify the 7×12 grid appears with 84 tiles.
2. Click two tiles with the same pattern that can be connected by ≤ 2 turns — confirm both disappear.
3. Click two different patterns — confirm the first selection switches to the new tile.
4. Click two matching tiles that cannot be connected — confirm the first selection switches.
5. Clear all pairs — confirm the game-over label shows "You Win!".
6. Use **Undo** to revert the last elimination.
7. Use **Redo** to reapply an undone elimination.
8. Press **Restart** to reset the board and history.
9. Press **Hint** (or press the **T** key) — confirm an orange-red line appears following the connectable path between a valid pair for 1.5 seconds.
10. Press **Shuffle** — confirm remaining tiles are reshuffled while empty spaces stay empty.
11. Create a dead-end board (or simulate one) and confirm the remaining tiles auto-shuffle when no matches exist.

## Security Considerations

- This is a local, single-player game with no network code, no external dependencies, and no sensitive data handling.
- No input validation concerns beyond the built-in GUI input handling.
- `.godot/` and `/android/` are excluded from version control via `.gitignore`.

## Notes for Agents

- The project is now a true 连连看 tile-matching game, not Tic-Tac-Toe. If asked to implement other mechanics (timer, scoring, hints, level generation), treat them as new features and extend the board/pathfinding/UI accordingly.
- The project uses `.png` assets referenced by Godot UID imports. Do not delete `.png.import` files; Godot regenerates them, but deleting them can break references until re-import.
- The `.editorconfig` only enforces `charset = utf-8`. Line endings are normalized to LF by `.gitattributes`.
- **Development Log**: After every code change, append a new entry to `DEVELOPMENT_LOG.md` at the project root. Each entry should include the date/time, affected files, reason for the change, and a brief description of what was modified.
- **Change Reporting**: When modifying code, always report to the user the affected file(s), exact location(s) (line numbers, node paths, function names, etc.), and the before/after modification content.
