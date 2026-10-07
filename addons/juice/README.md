# Juice

Game feel for **Godot 4.7+**: effects, sequences, camera shakes, springs, audio and haptics from one node.

[![Download Juice](download.svg)](https://github.com/genr234/cannoli/releases/download/latest-build/juice.zip)

[Full guide →](GUIDE.md) · [Cannoli →](https://github.com/genr234/cannoli)

## Install

Extract the ZIP into your project and enable **Juice** in **Project → Project Settings → Plugins**. Runtime classes also work without the editor plugin.

## Get started

1. Add a **JuicePlayer** beneath the node you want to affect.
2. Use **Add Feedback** in the inspector to pick effects, then **Play** to preview.
3. Trigger the player from your game:

```gdscript
@onready var hit_juice: JuicePlayer = $HitJuice

func take_damage(amount: int) -> void:
	hit_juice.play(global_position, amount / 10.0)
```

Feedbacks target the player's parent by default. Use `await hit_juice.play_async()` to wait for completion.

| Feature | Details |
| --- | --- |
| Effects | Transforms, visuals, camera, time, audio, UI and haptics |
| Sequences | Pauses, loops, reverse playback and shared presets |
| Tools | Inspector previews, timeline and live debugger |

Adjust motion, shake and flash intensity under **Project Settings → Juice → Accessibility**.

See the guide for [feedbacks](GUIDE.md#feedbacks), [channels and springs](GUIDE.md#concepts), [accessibility](GUIDE.md#accessibility) and [custom effects](GUIDE.md#writing-a-feedback).

[MIT](LICENSE).
