# Editing the menus in Godot

All game menus now have scene-authored controls. Open a scene in the 2D workspace to change its layout; use F5 to test it in the full game.

| Scene | What it contains |
| --- | --- |
| `preparation_ui.tscn` | Main menu, placement toolbar, upgrades, and the records host |
| `pause_screen.tscn` | Pause dialog and its Settings entry |
| `results_screen.tscn` | Run summary, leaderboard host, and shared footer |
| `leaderboard_panel.tscn` | Publishing form, rankings, pagination, and requests |
| `leaderboard_row.tscn` | Reusable row instantiated for each returned score |
| `settings_menu.tscn` | Audio and display settings |
| `build_controller.tscn` | Placement hint and the gameplay controller |

The main scene instances preparation, pause, results, and build controls. The HUD instances one leaderboard panel and moves that same panel between the records and results hosts, preserving its requests and form state.

Preparation owns its action buttons from the start. BuildController references them to update prices and perform purchases; it no longer creates or reparents them. Runtime scripts still update text, visibility, focus, and window fitting.

Some preparation controls are hidden in the editor's default home preview. Toggle their visibility in the Scene tree to inspect a different group, then undo the preview changes. Pause and results show example content in their own scene files; their scripts hide the overlays when the game starts. These scenes depend on the game controller, so use F5 for interactions rather than F6.

## Shared appearance

`game_theme.tres` supplies button states, panels, and text styles. `PrimaryButton` supplies the yellow Start/Continue action and its inset dark focus outline. `DialogPanel` includes 20 pixels of content padding; Settings retains its explicit MarginContainer and uses the unpadded base panel style.

Preparation fades its backgrounds to expose the arena. It duplicates only the StyleBoxes whose opacity changes so those adjustments cannot affect the shared Theme or other dialogs.

The live gameplay HUD and brightness indicator remain procedural/custom-drawn; they are not menus. `ui_style.gd` still supplies HUD helpers and viewport fitting, but its old button-style factory has been removed.

## Validation

Run `godot --headless --path . --script res://tests/check_menu_scenes.gd` for shared-theme isolation and small pause layouts. The existing menu, controller, keyboard, results, leaderboard, settings, and audio checks also exercise these scenes.
