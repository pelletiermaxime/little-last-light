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
