# Touch controls

The web build detects a touchscreen automatically. Landscape is the intended
play orientation; preparation menus also adapt to portrait.

- Hold the left half of the arena below the HUD and slide your thumb to steer.
  The joystick appears where you touch. Keep holding to keep moving, and lift
  to stop. Small movements give slower movement; the dead zone prevents drift.
- Tap **Brightness** on the right with another finger while moving.
- Tap **Pause** at the top right. Pausing, switching away from the browser,
  resizing, and ending a run clear held movement.
- Tap menu buttons. Swipe preparation cards to reach the remaining controls.
  Upgrade buttons retain their readable size instead of shrinking to fit.
- In placement, tap a turret to select it, then tap the arena to move it.
  Buying, selling, canceling, and hiding the toolbar use the existing buttons.
  Swiping the toolbar cannot place a turret behind it.

Keyboard and controller movement still work. The touch joystick does not add
extra speed to another input device or to diagonal movement.

## Trying the preview

The preview export is `export/touch-preview/index.html`. While its local server
is running, open <http://localhost:8073> on this computer, or
<http://10.0.0.6:8073> on a phone on the same local network. The network address
may change; this is a local preview, not an itch publication.

To serve the existing export again from the repository root:

```sh
rtk proxy python -m http.server 8073 --bind 0.0.0.0 --directory export/touch-preview
```

For a desktop visual preview of the touch layout, run Godot with user argument
`--touch-controls`. This displays the buttons and menus; it does not turn a
mouse into a multitouch device.

## Validation

- `tests/check_touch_controls.gd` checks touchscreen detection, readable menu
  layout, toolbar placement blocking, dead zone, analog movement, diagonal
  speed, independent fingers, brightness activation, synthetic mouse
  deduplication, cancellation, release, pause/resume, focus loss, resize, and
  results cleanup.
- Existing controller, pause, HUD, menu pages, build, menu scenes, input prompts,
  keyboard confirmation, upgrade navigation, and preparation UI checks pass.
- The release Web export succeeds. Chromium mobile emulation was exercised at
  844×390, at 1× and 3× pixel density, plus portrait resizing to 390×844.
  The exported game was checked visually and exercised with browser touch
  events for menu taps, swipes, turret movement, simultaneous movement and
  brightness, and pause. No JavaScript page errors were observed.
- Physical iPhone/Android feel, performance, browser chrome, and itch embedding
  still need a phone playtest. The itch page has not been changed or published.

Run the focused check from the repository root:

```sh
rtk proxy godot --headless --path . --script tests/check_touch_controls.gd
```
