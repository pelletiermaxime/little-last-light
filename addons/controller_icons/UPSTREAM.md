# Controller Icons

Vendored from https://github.com/rsubtil/controller_icons at commit
`4246544a5f0ddd32a33a5c8e837bed3bebec7c31`.

Addon code: MIT (see LICENSE). Bundled prompt assets: Xelu's FREE Controllers
& Keyboard PROMPTS, by Nicolae (XELU) Berbece, CC0; additional community icons
are also CC0. Source and credits: https://github.com/rsubtil/controller_icons#credits
and https://thoseawesomeguys.com/prompts/.

Little Last Light uses the addon's unmodified detection, default settings,
action-to-icon mapping, and prompt labels throughout the game. There is no custom
mapper, forced icon style, or browser detection fallback. InputControls forwards
events to the addon before handling game-specific menu and placement behavior,
and updates the interface in response to the addon's input_type_changed signal.
