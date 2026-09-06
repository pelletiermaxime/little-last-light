# Sound effects

Eight unmodified Kenney OGG files selected in the sound audition. Original CC0
licenses are preserved beside each pack's clips.

| Cue | Original pack / filename | Gain |
| --- | --- | --- |
| Menu focus / hover | Interface Sounds / click_003.ogg | -16 dB |
| Confirm | Interface Sounds / confirmation_001.ogg | -10 dB |
| Back / cancel | Interface Sounds / back_001.ogg | -12 dB |
| Place / move turret | Impact Sounds / impactWood_medium_000.ogg | -10 dB |
| Turret shot | Sci-Fi Sounds / laserSmall_001.ogg | -22 dB |
| Lantern damage | Impact Sounds / impactPunch_heavy_000.ogg | -12 dB |
| Successful upgrade | Interface Sounds / glass_001.ogg | -12 dB |
| Brightness change | Interface Sounds / toggle_001.ogg | -14 dB |

Sources (downloaded 2026-09-06):

- https://kenney.nl/assets/interface-sounds
- https://kenney.nl/assets/impact-sounds
- https://kenney.nl/assets/sci-fi-sounds

`game_audio.gd` owns one AudioStreamPlayer per cue. Shots have a shared 120 ms
cooldown and at most two overlapping voices; damage has a 250 ms cooldown.
Other cues have one voice each. Default sound volume is 50%, applied on top of
the gains above. Settings provides volume cycling (0/25/50/75/100%) and mute;
preferences live separately from progress in `user://audio-settings.cfg`.
Audio uses normal Godot playback without bus effects, including on Web.
