# Milestone 13: sound effects and settings

The game now has its first sound mix and a Settings page available from the
main menu and pause menu. All controls retain the vertical menu layout and
work with mouse, keyboard, and controller.

## Sound effects

Eight selected, unmodified Kenney clips cover menu navigation, confirmation,
back/cancel, turret placement, turret fire, lantern damage, upgrade purchases,
and brightness changes. Only successful game actions trigger their cues.

The mix starts quietly at 50% volume. Turrets share a 120 ms shot cooldown and
at most two overlapping voices; damage cues have a 250 ms cooldown. Pausing
stops combat sounds while menu sounds remain available. The unused audition
assets have been removed. Original CC0 licenses accompany the runtime clips.

See [the sound inventory](../audio/README.md) for sources and per-cue gains.

## Settings

- Audio volume and sound on/off.
- Fullscreen, borderless fullscreen, and windowed display modes.
- FPS limits of 60, 100, or Unlimited.
- VSync on/off.

Preferences persist separately from run progress. Windowed mode initially uses
85% of the available screen area, remembers manually resized dimensions, and
saves maximized state without overwriting the normal window size. Startup
restoration uses the root Window after initialization. Browser builds identify
display mode and VSync as browser-controlled rather than offering unsupported
desktop controls.

Closing Settings returns focus to its originating menu and keeps a paused run
paused. See [Settings details](settings.md).

## Keyboard menu fixes

Start run receives initial focus so native arrow-key navigation works on a
fresh main menu. Godot handles Enter and numpad Enter confirmation. The legacy
Enter-to-start shortcut only runs when nothing has focus, preventing it from
overriding a selected button. Returning home restores focus to Start run.

## Validation

The 22 Godot checks cover gameplay regressions, audio routing and overlap limits,
preference persistence, small-screen layouts, settings input isolation, and
keyboard navigation followed by confirmation. Headless checks cannot verify
native compositor behavior; desktop playtesting remains necessary for window
manager transitions. Web settings and persistence were also checked in-browser.
