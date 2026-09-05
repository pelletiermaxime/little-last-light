# Milestone 1: move the lantern, leave the turret

The game is running. Click its window, then use **WASD or the arrow keys** to move. **Space** still changes brightness. Walk away from the blue turret: its range circle should stay in place, while enemies head toward you.

## The main idea: parents carry their children

Previously, the scene looked like this:

```text
Main
└── Lantern
    └── Turret
```

A Node2D inherits its parent's transform. Moving the lantern therefore also moved its turret.

Now the scene in [main.tscn](../main.tscn) looks like this:

```text
Main
├── Lantern
└── Turret
```

They share a parent, so moving one does not move the other. In [main.gd](../main.gd), `_ready()` places the turret beside the lantern once, at startup. After that it stays there.

## The movement code

In [lantern.gd](../lantern.gd):

```gdscript
func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += direction * move_speed * delta
	_keep_inside_viewport()
```

`Input.get_vector()` turns the four movement actions into a direction. Right is `(1, 0)`, up is `(0, -1)`, and releasing everything gives `(0, 0)`. It also limits diagonal input so pressing two keys doesn't make you faster.

`move_speed` is 220 pixels per second. Multiplying by `delta`, the elapsed seconds for this physics step, gives the distance to travel during that step.

`_keep_inside_viewport()` limits the position to the screen, with a small margin. Resizing the window also applies this limit instead of teleporting the lantern back to the center.

The four actions and their keys are stored in [project.godot](../project.godot). You can also see them in **Project → Project Settings → Input Map**.

## One thing to try yourself

Select the Lantern node in Godot. Its script exposes **Move Speed** in the Inspector because the variable has `@export`. Try changing it from **220** to **120**, then run again. Notice how much harder it becomes to stay ahead of enemies.

If Godot asks about files changed on disk, reload those changes before editing.

## What was checked

Godot imported the project successfully. A short automated check verified straight movement, equal diagonal speed, the turret staying fixed, the lantern's screen boundary, and spawned enemies targeting the lantern. The graphical game also launched successfully using the Intel renderer. How movement feels is the next thing to judge by playing.

