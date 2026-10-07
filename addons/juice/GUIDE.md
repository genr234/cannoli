<img src="icon.svg" width="64" height="64" alt="">

# Juice

Game feel for Godot 4.7+: squashes, shakes, flashes, hit stops, springs, sounds, rumble and floating numbers, played in sequence from one node.

A **JuicePlayer** holds a list of **feedbacks**. Each feedback is one effect: scale a node, shake the camera, flash the screen, freeze the game for 80 ms, play a sound. Call `play()` and the list runs. The same list can run in reverse, stop halfway, skip to the end, or put every target back as it was.

## Setup

1. Enable **Juice** in **Project → Project Settings → Plugins**. This adds the inspector tools, the debugger tab and the `juice/*` project settings. The runtime classes work without it.
2. Add a **JuicePlayer** as a child of the node you want to affect. Feedbacks target the player's parent unless you give them a path.
3. Press **Add Feedback** in the inspector and pick effects. Press **Play** to preview them in the editor. Values are restored when the preview ends.
4. Call `play()` from your game:

```gdscript
@onready var hit_juice: JuicePlayer = $HitJuice

func take_damage(amount: int) -> void:
	hit_juice.play(global_position, amount / 10.0)  # position, intensity
```

`play()` returns false when nothing started (cooling down, the chance roll failed, out of range). `await hit_juice.play_async()` waits for the end.

Feedbacks can also be built in code:

```gdscript
var player := JuicePlayer.new()
var punch := JuiceScale.new()
punch.duration = 0.25
punch.remap_one = Vector3(0.4, 0.4, 0.4)  # grow by 40%, then back
var stop := JuiceFreezeFrame.new()
stop.duration = 0.06
player.feedbacks = [punch, stop]
add_child(player)
player.play()
```

## Concepts

**Sequence.** Feedbacks start together unless the list holds a **JuicePause** (waits a time, or until `resume()`), a **JuiceHoldingPause** (waits for everything above it), or a **JuiceLooper** (jumps back up the list, a number of times or forever; **JuiceLooperStart** marks where to). `get_total_duration()` works it out, and the inspector timeline draws it.

**Timing.** Every feedback has an initial delay, cooldown, repeats, a chance to play, a play limit, an intensity window and a direction condition. It can also snap its start to a beat (`quantize_to_bpm`). Feedbacks run on scaled or unscaled time. The player's own waits are unscaled by default, so a hit stop never freezes the sequence that started it.

**Direction.** `play_reversed()` or `direction = BACKWARD` walks the list bottom to top, and every curve plays backwards. `auto_flip_direction_on_end` turns a player into an open/close toggle.

**Intensity.** `play(position, intensity)` scales every effect. Feedbacks can ignore it (`constant_intensity`), randomize it, or only play inside a window (`use_intensity_interval`), so one player can hold a light and a heavy version of a hit.

**Restore.** Feedbacks remember their target as they found it. `restore_initial_values()` puts everything back, `stop()` interrupts, `skip_to_end()` jumps to the final state.

**Presets.** Players duplicate their feedbacks at runtime, so one feedback resource can be shared by many players. In the inspector's **List** menu, **Save as preset** writes the list to a `JuicePreset` file, and **Load preset** or dropping the file on the panel adds it to another player.

**Targets.** A feedback's `target` path is relative to the player. Empty means the automatic target: the parent (default), the player itself, or a child.

**Channels and shakers.** Some feedbacks don't touch nodes directly. They broadcast on a channel (a number or a `JuiceChannel` resource), and **shakers** on that channel react. A shaker is a node: put a `JuiceCameraShaker` on the camera, and every `JuiceCameraShake` on channel 0 shakes it, from any scene. Feedbacks with **Range** settings only reach shakers within a distance, with an optional falloff. Several shakers on the same property add up and always return it to its rest value.

**Camera.** `JuiceCameraShaker` shakes `Camera2D` (offset and rotation) and `Camera3D` (view offset or transform). Beside timed shakes it keeps **trauma**: hits add trauma, trauma decays every second, and the shake grows with trauma squared, so small hits stay subtle and many hits pile up. Camera feedbacks have a `direct` option that needs no shaker: the feedback adds one to the current camera by itself.

```gdscript
$Camera2D/JuiceCameraShaker.add_trauma(0.3)
```

**Springs.** `JuiceSpring` is a damped spring for floats, vectors and colors. A `JuiceSpringNode` springs any `node:property` (or position, rotation, scale, squash and stretch, the time scale), and listens on a channel so a `JuiceSpringFeedback` can bump it from anywhere. `JuicePositionSpring`, `JuiceRotationSpring`, `JuiceScaleSpring` and `JuiceSquashSpring` spring their target without a node.

```gdscript
$Coin/JuiceSpringNode.bump(Vector2(0, -1200))  # a 2D coin hops up
```

**Floating text.** Put a `JuiceFloatingTextSpawner` in the scene (2D, UI or 3D) and play a `JuiceShowText` feedback, or call the spawner directly. Texts are pooled, and move, fade, scale and change color over their lifetime.

**Sequencer.** `JuiceSequence` is a step-sequencer pattern (tracks × steps, BPM). `JuiceSequencer` plays it, firing a `JuicePlayer`, a sound or a signal for each note. `JuiceInputSequenceRecorder` records a pattern from input actions.

## Accessibility

Every feedback belongs to a category: motion, shake, flash, time, audio, haptics or other. Each category has an intensity multiplier in **Project Settings → Juice → Accessibility**, and at runtime:

```gdscript
Juice.set_multiplier(Juice.CATEGORY_SHAKE, 0.0)   # "screen shake" option off
Juice.set_multiplier(Juice.CATEGORY_FLASH, 0.5)
Juice.set_flash_rate_cap(3.0)                     # at most 3 flashes per second
Juice.set_enabled(false)                          # everything off
```

The flash rate cap limits full-screen flashes for photosensitive players.

## Editor

- **Transport bar** on every player: play, play reversed, stop, pause, skip to end, restore, and the total duration.
- **Timeline** above the feedback list: one row per feedback with its color, an active toggle, a ▶ to preview it alone, and a bar showing when it starts and how long it lasts, with repeats, pauses and loops.
- **Add Feedback**: a searchable list of every feedback, by folder. Edits can be undone.
- **List** and row menus: copy, paste, duplicate, move, remove, presets.
- **Debugger → Juice**: the players running in the game, with their progress.

## Feedbacks

| Group | Feedbacks |
| --- | --- |
| Transform | `JuicePosition`, `JuiceRotation`, `JuiceScale` (absolute, additive or to a destination, per-axis curves), `JuiceSquashAndStretch`, `JuiceWiggle`, `JuiceLookAt`, `JuiceRotateAround`, `JuiceDestination`, `JuiceSetParent` |
| Generic | `JuiceProperty`: any number, vector or color property of any node |
| Shake | `JuicePositionShake`, `JuiceRotationShake`, `JuiceScaleShake`, `JuicePropertyShake`, `JuicePlayerShake` (to the matching shakers) |
| Camera | `JuiceCameraShake` (shake or add trauma), `JuiceCameraZoom`, `JuiceCameraFov`, `JuiceCameraOrthoSize`, `JuiceCameraClipping` |
| Visual | `JuiceModulate`, `JuiceFlicker`, `JuiceBlink`, `JuiceFlash`, `JuiceFade`, `JuiceShaderParam`, `JuiceShaderGlobal`, `JuiceSpriteFrame`, `JuiceTextureOffset`, `JuiceLight`, `JuiceParticles`, `JuiceTrail` |
| Environment | `JuiceGlow`, `JuiceColorAdjust`, `JuiceDepthOfField`, `JuiceFog`, `JuiceScreenEffect` (vignette, chromatic aberration, lens distortion, zoom punch) |
| Time | `JuiceTimeScale`, `JuiceFreezeFrame` (whole game, or only some nodes) |
| Audio | `JuiceSound` (pooled, random clips, 2D/3D), `JuiceAudioPlayerControl`, `JuiceAudioPitch`, `JuiceAudioVolume`, `JuiceAudioPan`, `JuiceBusEffect`, `JuiceBusVolume` |
| UI | `JuiceProgress`, `JuiceTypewriter`, `JuiceText` (set or count up), `JuiceFontSize`, `JuiceControlLayout`, `JuiceCanvasAlpha` |
| Haptics | `JuiceHaptics`: presets, patterns or a continuous curve, on gamepads and phones |
| Physics | `JuiceImpulse`, `JuiceCollision` |
| Scene | `JuiceInstantiate` (pooled), `JuiceFree`, `JuiceSetActive`, `JuiceLoadScene` |
| Springs | `JuiceSpringFeedback`, `JuicePositionSpring`, `JuiceRotationSpring`, `JuiceScaleSpring`, `JuiceSquashSpring` |
| Flow | `JuicePause`, `JuiceHoldingPause`, `JuiceLooper`, `JuiceLooperStart`, `JuiceSignal`, `JuiceLog`, `JuicePlayerControl`, `JuiceChain`, `JuiceBroadcast`, `JuiceShowText` |

## Nodes and resources

| Class | What it does |
| --- | --- |
| `JuicePlayer` | Plays a list of feedbacks. |
| `JuiceFeedback` | Base class of every feedback. |
| `JuiceTween` | Easing: a preset, a Godot transition and ease, or a `Curve`. |
| `JuiceChannel` | A named channel for broadcasts. |
| `JuicePreset` | A saved feedback list. |
| `JuiceCameraShaker`, `JuiceZoomShaker`, `JuiceClippingPlanesShaker` | Camera shakers. |
| `JuicePositionShaker`, `JuiceRotationShaker`, `JuiceScaleShaker`, `JuicePropertyShaker`, `JuicePlayerShaker` | Node shakers. |
| `JuiceListener` | Reacts to a `JuiceBroadcast` with a signal or a player. |
| `JuiceSpring`, `JuiceSpringNode` | Springs. |
| `JuiceFloatingTextSpawner` | Pooled floating texts. |
| `JuiceSequence`, `JuiceSequencer`, `JuiceInputSequenceRecorder` | Step sequencer. |
| `JuiceHapticPattern` | A vibration pattern. |
| `JuiceTimeScaleStack` | Overlapping time scale changes; use it for your own slow motion too. |
| `Juice` | Global switch, accessibility multipliers and the channel bus. |

## Writing a feedback

Extend `JuiceFeedback`, start the script with `@tool`, and override what you need:

```gdscript
@tool
class_name JuiceBlinkLabel
extends JuiceFeedback

@export_group("Blink")
@export var duration := 0.5

var _initial := Color.WHITE


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_FLASH


func _on_initialize() -> void:
	var node := get_target() as CanvasItem
	if node != null:
		_initial = node.modulate


func _on_progress(progress: float) -> void:
	var node := get_target() as CanvasItem
	if node != null:
		node.modulate.a = lerpf(1.0, 0.2, sin(progress * PI) * get_intensity())


func _on_restore() -> void:
	var node := get_target() as CanvasItem
	if node != null:
		node.modulate = _initial
```

`_on_progress` gets 0 to 1, or 1 to 0 when playing in reverse. Instant feedbacks return 0 from `_get_duration()` and work in `_on_play()`. Don't use `await`, timers or tweens inside a feedback; the player's clock is what makes reverse, skip and restore work.
