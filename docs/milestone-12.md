# Milestone 12 playtest: a full arena and focused preparation

The game now uses the entire window as its arena. Preparation shows the lantern and turret layout behind a centered transparent card. Its buttons form one vertical stack with consistent spacing: **Start run**, **Place turrets**, **Buy upgrades**, **Records**, and desktop **Quit Game**. The desktop window remains maximized.

## A smaller set of decisions at a time

The home card shows available energy, turret count, and maximum health. Records and desktop Quit Game remain secondary actions.

Placement opens a transparent vertical card on the left for buying, moving, selling, and refunding turrets. Clicking an existing turret selects it only in this view. B still begins a purchase; Escape cancels an active placement, then returns home when pressed again. Done also restores a moving turret before leaving. The background passes placement clicks through to the arena. Buttons stay clickable; Tab or Hide controls hides the card without canceling placement, allowing turrets underneath buttons too.

Upgrades open a separate card containing damage, fire rate, and health purchases. U opens this card; G/F/H and the existing controller shortcuts still buy their corresponding upgrades. Phase, funds, placement, and cap checks remain in Main.

During combat, preparation disappears. Plain health text and a thin bar sit at the top left; time and earnings sit at the top center without card backgrounds. A small three-segment brightness indicator along the bottom cycles levels when clicked and displays the active level and income. Esc/P/Options still pause; there is no on-screen Pause button. The boss health bar appears below the timer. The FPS counter moves to the bottom left. Results still show the completed run before returning home.

## The idea to learn: UI does not define world bounds

Previously, Main subtracted a sidebar width from the viewport. Now `get_arena_rect()` returns the full viewport, consistently during preparation and combat. The lantern, spawns, turret placement, and boss arrival all use that rectangle.

Saved turret coordinates were already normalized to the arena. Loading scales them to the full arena without deleting turrets or changing purchased upgrades. The arena is wider at a given window size, which can affect encounter timing and should be considered in later difficulty tuning.

UI coverage is temporary, not a permanent forbidden strip. In placement mode, container backgrounds ignore mouse input while buttons keep receiving it. The world-selection handler blocks only visible buttons, so mouse and controller can place through the card background. Hiding the controls reveals button-covered ground.

## Separate view state from run state

`PreparationUI.View` contains HOME, PLACEMENT, UPGRADES, and RECORDS. These all belong to the existing PREPARATION phase; changing cards never starts or finishes a run.

BuildController retains placement and refund behavior. PreparationUI arranges its action buttons and selects which are visible. GameHUD displays combat information, and `ui_style.gd` gives cards and buttons shared colors, margins, and focus outlines.

The single leaderboard panel moves between the Records card and the results screen. It keeps its request and retry state rather than creating a new network request object with every view change.

## Verification

The UI integration check covers full arena bounds, home actions, background click-through, hiding controls, canceling a move, purchases, records, pause/results transitions, and saved layout restoration. Existing suites retain coverage of health, income, boss behavior, refunds, controllers, and leaderboard publication.

Rendered previews exercise home, placement, upgrades, and combat. Menus use finite pages and scale to fit short windows, with preparation actions in a single column.

Start with [preparation_ui.gd](../preparation_ui.gd), [game_hud.gd](../game_hud.gd), and [tests/check_preparation_ui.gd](../tests/check_preparation_ui.gd).

### Controller prompts and navigation

`input_controls.gd` owns active-device detection and controller menu routing. It reads each action’s controller binding from InputMap and draws cached SVG button glyphs for PlayStation, Xbox, or an unknown pad’s button positions. Standard menu confirmation has no icon; dedicated shortcuts stay visible. Keyboard/mouse activity restores keyboard prompts; stick drift and mouse jitter are ignored. The node runs while paused and receives events before the other scene nodes, consuming menu confirms once so a button press cannot also place a turret or change brightness.

Menus navigate with the stick or D-pad. Placement uses the stick for the world cursor and the D-pad for toolbar focus; moving the stick releases toolbar focus. Triangle/Y toggles the placement card, R1/RB sells the selected turret, and upgrades/refunds use menu confirmation instead of purchase shortcuts. The new `check_input_prompts.gd` exercises prompt families, drift, focus, single purchases, pause/results, and disconnection. Username entry still requires a keyboard; controller-only text entry is future work.

### Menus without scrolling

Standard controller navigation instructions and the Done and pause-resume controller hints are omitted. Yellow primary buttons use an inset dark navy focus outline. The leaderboard navigation row appears only when a record is available to publish, avoiding a redundant Rankings button.

The results screen separates the run summary from its leaderboard page and keeps Continue in a shared footer. The leaderboard separates publishing from rankings, showing three ranks per page with Previous/Next controls. Preparation uses a plain margin container. No in-game menu uses a ScrollContainer; short windows scale finite cards to fit through `UIStyle.fit_card()`. `check_menu_pages.gd` verifies that actions remain inside a 640×480 viewport, including publication, rankings, pagination with a controller, and all preparation views.
