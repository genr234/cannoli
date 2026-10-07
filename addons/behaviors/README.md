<img src="icon.svg" width="64" height="64" alt="">

# Behaviors

Behavior trees for Godot 4.7+: a graph editor, conditional aborts, shared variables, subtrees, utility AI, perception, steering and a live debugger.

A **BehaviorTree** is a resource made of **tasks**. Actions do things (move, play a sound, set a variable), conditions check things (can I see the player?), composites run their children in some order, and decorators change how one child runs. A **BehaviorAgent** node runs a tree for the character it's attached to.

## Setup

1. Enable **Behaviors** in **Project → Project Settings → Plugins**. This adds the **Behaviors** main screen, the inspector tools, the debugger tab and the `behaviors/*` project settings. The runtime classes work without it.
2. Add a **BehaviorAgent** as a child of your character. The character (the agent's parent) is the **actor** that tasks act on.
3. Select the agent and press **Create Tree** in the Behaviors screen, or assign an existing tree file.
4. Add tasks from the **Tasks** palette, the right-click menu, or **Space** for quick search. Connect a parent's right port to a child's left port. Run the game.

```gdscript
@onready var brain: BehaviorAgent = $BehaviorAgent

func _on_hurt(attacker: Node2D) -> void:
	brain.set_variable(&"threat", attacker)
	brain.send_event(&"hurt", [attacker])
```

Trees can also be built in code:

```gdscript
var chase := BehaviorSequence.new()
var see := BehaviorCanSee.new()
see.target_group = &"player"
see.store_target = "target"
var seek := BehaviorSeek.new()
seek.bindings[&"target"] = "target"  # read the target from the variable
chase.children = [see, seek]
var tree := BehaviorTree.new()
tree.root = chase
$BehaviorAgent.tree = tree
```

## The graph

Trees read left to right. The Entry node runs one root task, and each parent runs its children **top to bottom**: drag a node up or down to change the order. Tasks that aren't connected to anything stay in the file but never run.

Each node shows its icon, name, a short summary ("2s", "×3", "hp > 10"), its comment, warnings, and the abort type of composites. Right-click a node to disable it (disabled tasks count as a success), set a breakpoint, collapse its branch or export it as a subtree. **Arrange** tidies the layout, and frames group nodes under a title. The **⚠** button lists every problem in the tree; click one to jump to the task.

Writing a task is writing a script:

```gdscript
@tool
class_name LowHealth
extends BehaviorCondition
## Succeeds while the actor's health is under a threshold.

@export var threshold: float = 25.0


func _on_update(_delta: float) -> Status:
	return Status.SUCCESS if actor.health < threshold else Status.FAILURE
```

It shows up in the palette under **Custom** (or its folder name) with its doc comment as the tooltip. The task API: `_on_awake`, `_on_start`, `_on_update(delta) -> Status`, `_on_physics_update(delta)`, `_on_end`, `_on_pause(paused)`, `_on_tree_complete(status)`, `_get_priority`, `_get_utility`, `_get_warnings`, `_get_graph_text`. Tasks reach the `actor`, the `agent`, the `blackboard`, and `get_var()` / `set_var()`.

## Concepts

**Status.** A task returns `RUNNING` to be ticked again, or ends with `SUCCESS` or `FAILURE`. Its parent decides what to do next.

**Variables.** Tasks share data through variables declared in the **Variables** panel. Any property of a task can be **bound** to a variable in the inspector. The task then reads the variable before it runs and writes it back if it changed it, so task code only touches its own properties. Variables are typed. They can be **mapped** to a node property (reading the variable reads the node), marked to persist in saves, and overridden per agent (`variable_overrides`). Writing a name nobody declared creates it on the spot.

**Global variables.** Variables every tree can read live in a `BehaviorVariableSet` file set in **Project Settings → Behaviors → Variables**. The Globals tab creates one. Tasks reach them with the `global/` prefix; code uses `Behaviors.get_global()` and `Behaviors.set_global()`.

**Conditional aborts.** Composites can keep checking conditions that already ran and interrupt what runs now when a result changes:

- **Self**: the composite's own conditions interrupt its running child. A sequence of *Can See Player* → *Chase* stops chasing the moment the player is out of sight.
- **Lower priority**: the composite's conditions keep being checked after it ended, while anything to its right runs. A selector with *[Can See Player → Attack]* above *[Patrol]* drops the patrol as soon as the player shows up.
- **Both**: both of the above.

The **Observe Variable** decorator does the same for a single variable, and only re-checks when that variable changes.

**Events.** `agent.send_event(&"alarm", [position])`, the **Send Event** task, or `Behaviors.send_event_to_group(&"guards", &"alarm")` send an event. **Has Received Event** succeeds once it arrives and can store the arguments in variables. Put it under a lower-priority abort to react while the tree is busy elsewhere. Code can listen with `agent.register_event()` or the `event_received` signal.

**Subtrees.** A **Subtree** task runs another tree file in its place. Variables with the same name are shared with the outer tree; the rest stay inside the subtree. Each Subtree task can override the subtree's variables, so one *Attack* tree can serve a sword and a bow. In the graph, double-click a Subtree to open it, and **Back** to return.

**Utility AI.** A **Utility Selector** runs the child with the highest score, re-scored every tick. Score children without code: add **considerations** to a task (variable → input range → `Curve` → weight), and the scores multiply. Or override `_get_utility()`. `switch_margin` stops two close scores from flipping back and forth.

**Ticking.** Agents tick every frame by default. `tick_interval` slows a tree down, `tick_mode` can follow physics frames or wait for `agent.tick(delta)`, and **Project Settings → Behaviors → Runtime → Max Agents Per Frame** spreads many agents over several frames. A task can start at most once per tick (`execution_limit`), so a repeater never locks up a frame. Unticking **Instant** on a task makes the tree wait a tick after it.

**Restarting.** `restart_when_complete` loops the tree, `reset_values_on_restart` resets it, `pause_when_disabled` keeps its place while `enabled` is off, and `start()`, `stop(pause)`, `restart()` control it from code. The `started`, `restarted`, `finished` and `stopped` signals report it.

## Tasks

**Composites.** Sequence, Selector, Parallel, Parallel Selector, Parallel Complete, Priority Selector, Random Selector, Random Sequence, Weighted Random Selector, Selector Evaluator (re-runs higher-priority children every tick), Utility Selector.

**Decorators.** Inverter, Repeater, Return Success, Return Failure, Until Success, Until Failure, Retry, Cooldown, Timeout, Delay, Chance, Run Once, Interrupt (with **Perform Interruption**), Conditional Evaluator, Task Guard (a semaphore shared by key, per agent or global), Observe Variable, Subtree.

**Basic.** Wait, Idle, Log (with `{variable}` placeholders), Send Event, Has Received Event, Random Probability, Start Tree, Stop Tree, Restart Tree, Stacked Action and Stacked Condition (several tasks in one node).

**Variables and logic.** Set, Operate (math on numbers, vectors, colors and strings), Random Value, Clamp, Toggle, Compare, Is Set. **Evaluate Expression** and **Expression Condition** run a Godot expression with every variable as an input, plus `actor`, `agent`, `delta` and `globals`: `health < 30 and ammo > 0`.

**Nodes and reflection.** Get Property, Set Property, Call Method, Compare Property, Find Node, Find In Group (first, random, nearest, farthest), Instantiate Scene, Free Node, Set Visible, Set Process Mode, Add To Group, Remove From Group, Is In Group, Is Node Valid, Is Visible.

**Signals.** Wait For Signal (stores the arguments, optional timeout) and Emit Signal.

**Animation and audio.** Play Animation, Stop Animation, Set Animation Tree Parameter, Travel To State, Is Animation Playing, Is In State, Play Sound (random pitch and volume), Stop Sound, Is Sound Playing, Tween Property.

**Input and time.** Is Action Pressed, Get Input Axis, Get Input Vector, Set Time Scale.

**Movement.** Seek, Flee, Pursue, Evade, Wander, Patrol, Follow, Face, Move To, Set Navigation Target, Has Arrived, Is Target Reachable. They work in 2D and 3D: a `CharacterBody2D`/`3D` gets its velocity set and `move_and_slide()` called, any other node is moved directly, and a `NavigationAgent2D`/`3D` among the actor's children is followed when there is one. Speeds and distances are in world units, which means pixels in 2D, so raise the defaults for 2D games.

**Perception and physics.** Can See (field of view, distance, line of sight), Can Hear (noises from `Behaviors.emit_noise()`, the **Emit Noise** task or a **BehaviorNoiseEmitter** node), Is Within Distance, Raycast, Has Entered Area, Has Exited Area, Is On Floor.

## Nodes

**BehaviorVariableSync** keeps agent variables and node properties in step: agent to node, node to agent, or both. Use it to show an agent's state in the UI without code.

**BehaviorNoiseEmitter** makes noises that **Can Hear** picks up, from code or when a signal fires.

## Debugging

Run the game from the editor and open the **Behaviors** tab of the debugger. Pick an agent and its tree opens in the Behaviors screen with live colors: running tasks are highlighted, finished tasks show ✓ or ✗, and conditions re-checked by an abort show ↻. The variables table updates live, and you can edit values while the game runs. The history slider steps back through the last ticks. Pause, resume, restart or stop the agent from the tab.

A **breakpoint** on a task pauses the game when the task starts. `log_task_changes` on an agent prints every start, end and abort.

## Integrations

These turn on by themselves when the other cannoli package is installed.

- **Save**: give an agent a `save_key` and its persistent variables are saved and loaded with the slot, along with the global variables.
- **Relationships**: Compare Affinity, Is In Faction Tier and Add Deed tasks.
- **Quests**: Quest State Is and Set Quest State tasks.
