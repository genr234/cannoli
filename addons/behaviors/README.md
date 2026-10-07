# Behaviors

Behavior trees, utility AI, perception and steering for **Godot 4.7+**, with a graph editor and live debugger.

[![Download Behaviors](download.svg)](https://github.com/genr234/cannoli/releases/download/latest-build/behaviors.zip)

[Full guide →](GUIDE.md) · [Cannoli →](https://github.com/genr234/cannoli)

## Install

Extract the ZIP into your project and enable **Behaviors** in **Project → Project Settings → Plugins**. Runtime classes also work without the editor plugin.

## Get started

1. Add a **BehaviorAgent** beneath your character. Its parent is the actor tasks control.
2. Select the agent and press **Create Tree** in the **Behaviors** screen.
3. Add tasks from the palette and connect parent outputs to child inputs. Children run from top to bottom.
4. Run the game and pass variables or events from code:

```gdscript
@onready var brain: BehaviorAgent = $BehaviorAgent

func _on_hurt(attacker: Node2D) -> void:
	brain.set_variable(&"threat", attacker)
	brain.send_event(&"hurt", [attacker])
```

Tasks return `RUNNING`, `SUCCESS` or `FAILURE`. Open **Debugger → Behaviors** to inspect agents, edit variables and step through tick history.

| Feature | Details |
| --- | --- |
| Decisions | Conditional aborts, subtrees and utility scoring |
| Tasks | Movement, perception, variables, signals, animation and more |
| Tools | Graph validation, breakpoints and live debugging |

Save, Relationships and Quests integrate automatically when installed; all are optional. Movement works in 2D and 3D; increase default speeds for pixel-based 2D worlds.

See the guide for [concepts](GUIDE.md#concepts), [tasks](GUIDE.md#tasks), [custom tasks](GUIDE.md#the-graph) and [integrations](GUIDE.md#integrations).

[MIT](LICENSE).
