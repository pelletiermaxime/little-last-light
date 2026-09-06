# Controller Icons integration

Controller Icons owns active-device detection, controller-family selection,
keyboard/mouse switching, connection handling, prompt artwork, icon caching,
and prompt labels. The addon and its settings are unmodified, including its
default Xbox 360 fallback for unidentified controllers.

InputControls forwards input to the addon before consuming gameplay/menu events,
then responds to its input_type_changed signal. Godot sends input through the
scene tree in reverse order, so handled menu events would otherwise never reach
the addon autoload. Automatic addon input processing is disabled while this
forwarding node exists and restored when it leaves.

The remaining game code handles menu focus/repeat, placement, pause, and preventing
one button press from triggering multiple actions. Prompt queries use the addon's
default parse_path() and parse_path_to_tts() behavior without forced styles.
Menu confirmation buttons remain icon-free as requested. Sell turret uses R1/RB.

## Browser trial

There is no custom controller-name detection, hardware-ID matching,
JavaScriptBridge lookup, custom mapper, or positional fallback override. Test the
addon's default detection in Firefox/Linux with the Bluetooth PS5 controller
before deciding whether any compatibility extension is necessary. Earlier tests
with a custom browser-ID fallback do not establish the result for this version.

The stock-addon browser trial with simulated Firefox ID
`054c-0ce6-Wireless Controller` selected the addon's Xbox 360 fallback, displaying
X and Y. The user subsequently confirmed that the stock-addon version displays
the PS5 icons with their actual Firefox/Linux/Bluetooth controller setup.
No custom detection workaround is needed for that confirmed setup.

## Validation

tests/check_input_prompts.gd exercises addon-driven input switching and prompt
assets, drift, menu navigation, toolbar controls, one-action confirmation,
pause/results transitions, and disconnect behavior. The addon's prompt-label API
is used for controller tooltips. Keyboard buttons already include their shortcut
in their text, so their tooltips reuse that text without asking for a localized
physical-key name (unsupported by Godot's Web and headless display servers).

Addon revision and licensing: [UPSTREAM.md](../addons/controller_icons/UPSTREAM.md).
