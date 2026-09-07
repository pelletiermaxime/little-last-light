# Settings

Open Settings from the main menu or pause menu. Changes apply immediately and
persist separately from run progress. Done, Escape, or controller Back returns
to the menu that opened it; leaving Settings never resumes a paused run.

- Audio: volume in 25% steps and sound on/off. Existing audio preferences remain
  in `user://audio-settings.cfg`.
- Display mode: Fullscreen (Godot exclusive fullscreen), Borderless fullscreen
  (Godot fullscreen), or Windowed. Switching out of a window remembers its size;
  returning restores a decorated, resizable window that fits the current screen.
  The initial window uses 85% of the usable screen area and is centered. Resizing
  saves the new size after a short delay, including while paused, and on quit.
  Maximizing with the window manager is saved separately: the game reopens
  maximized while retaining the normal size for unmaximizing. Fullscreen and
  minimize transitions do not overwrite that normal window state.
  Fullscreen and borderless fullscreen behave identically under Wayland.
- FPS limit: 60, 100, or Unlimited (`Engine.max_fps = 0`).
- VSync: on/off. The display refresh rate and system compositor can impose
  additional limits regardless of the requested FPS setting.

Display preferences are in `user://display-settings.cfg`. Web builds offer
audio and FPS controls; display mode and VSync are labeled browser-controlled
and disabled because the browser owns the window and frame presentation.

## Assistance prototype

Settings → Assistance offers three independent switches, editable in preparation:

- Half-price upgrades: all eight upgrade families cost 50% less. Turret purchase
  and sell prices are unchanged.
- Short night: the encounter timeline advances twice as fast. The Drencher arrives
  at 2:30 and the Snuffer at 7:30; Gathering/Pressure/Recovery, charger unlocks,
  and health/pressure progression use that same timeline. The HUD and results
  show real elapsed time. Spawn cadence, income, attack warnings and boss combat
  clocks retain their normal durations, leaving less grinding before the finale.
- Half-speed enemies and projectiles: pursuers, charger approaches and charges,
  both bosses' movement, and Snuffer droplets move at 50% speed. Pulse slow still
  stacks with movement assistance; warning and attack clocks remain readable.

These settings are saved with game progress, unlike audio/display preferences.
Enabling any switch immediately marks that progress as assisted and removes a
pending publication. Switching it off does not clear this marker: discounted
upgrades and energy earned with assistance carry forward into later runs.
Assisted runs still bank energy and show their result, but do not set local
competitive records or publish online. The live HUD, results, settings and
leaderboard panel identify assisted progress. Rankings remain available to read.
Reset all progress clears assists and their marker; already published scores stay.
During a run the submenu is readable, but its switches are locked.

Playtest with disposable progress: enable each switch, check upgrade prices,
start a short night, inspect the assisted HUD and pause-settings lock, then check
the 2:30/7:30 arrivals and result. Disable all switches and restart the game;
publishing must remain disabled. Reset progress to confirm normal eligibility.
Use `tests/check_assistance.gd` for deterministic boundaries and save regression.
