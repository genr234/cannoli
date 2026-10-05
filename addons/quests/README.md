<img src="icon.svg" width="64" height="64" alt="">

# Quests

Hand-written and procedurally generated quests for Godot 4.7+.

A quest is a graph of **nodes**. The start node activates first. Each node waits for its **conditions** (a counter reaching a value, a message, a timer, other quests…), then becomes true, runs its **actions** and activates its children. Reaching a success or failure node ends the quest. Each quest and node state carries **content** (headings, text, icons, buttons) for the dialogue UI, journal and HUD.

**Quest givers** offer quests to the player's **journal**. The **generator** looks at the world around an NPC, decides what bothers it most (orcs in the forest, a rival faction), plans a series of steps to fix it, and builds a quest from the plan.

## Setup

1. Enable **Quests** in **Project → Project Settings → Plugins**. This adds the **Quests** editor tab, inspector editors and the debugger tab. The runtime classes work without it.
2. Create a **QuestDatabase** resource and add quests in the **Quests** tab, or start from a template (**Talk to NPC**, **Collect N**, **Kill N**, **Timed delivery**, **Chain**).
3. Add a **QuestManager** node to your main scene and assign the database. Instance `res://addons/quests/ui/quest_ui.tscn` for the default dialogue, journal, HUD and alerts; it fills the manager's empty UI slots.
4. Add a **QuestJournal** to the player and a **QuestGiver** to each NPC, with a **QuestIdentity** (id and display name) on each character. List the giver's quests in its `quests` property.
5. Tell quests what happens, by message or in code:

```gdscript
# Counters listen for messages. A "Kill N wolves" quest counts this:
Quests.send_message("Killed", "Wolf")

# Talking to a giver opens the dialogue UI with its offers and active quests:
$QuestGiver.start_dialogue(player)

# Reading and changing quests:
Quests.get_quest_state("pesky_rabbits")            # Quest.State.ACTIVE
Quests.counter("pesky_rabbits", "rabbits")         # 3
Quests.set_quest_state("pesky_rabbits", Quest.State.SUCCESSFUL)
Quests.give_quest("coin_race")                     # straight into the player's journal
```

Press <kbd>J</kbd> (action `quests_toggle_journal`, added at runtime if missing) to toggle the journal.

## Concepts

**Quest states.** `WAITING_TO_START`, `ACTIVE`, `SUCCESSFUL`, `FAILED`, `ABANDONED`, `DISABLED`. A quest waiting to start checks its **autostart** conditions (start by itself) and **offer** conditions (a giver may offer it). `infinitely_repeatable`, `max_times` and `cooldown_seconds` control repeats; `is_abandonable`, `remember_if_abandoned` and `delete_when_complete` control what happens after.

**Nodes.** Types are `START`, `PASSTHROUGH` (true as soon as it's active), `CONDITION` (true when its conditions are met), `SUCCESS` and `FAILURE`. A node becomes active when a parent becomes true. Set `join_mode` to `ALL` or `MIN` to wait for several parents instead; optional parents don't count toward `ALL`. Each node's `speaker` decides who talks about it in dialogue (empty means the giver).

**Conditions.** A condition set is true when `ANY`, `ALL` or at least `min_condition_count` conditions are true.

| Condition | True when |
| --- | --- |
| `QuestCounterCondition` | A counter is at least / at most a value (a literal or another counter). |
| `QuestMessageCondition` | A message arrives, optionally from a sender, to a target, with a value. |
| `QuestTimerCondition` | A counter used as a timer counts down to 0. |
| `QuestParentCondition` | Any / all / at least N parent nodes are true. |
| `QuestStateCondition`, `QuestNodeStateCondition` | Another quest or node is in a state. |
| `QuestExpressionCondition` | A GDScript expression is true, e.g. `counter("rabbits", "killed") >= 3 and is_at_least_tier("Guards", "Player", "Friendly")`. |
| `QuestRelationshipCondition` | A faction's affinity or tier toward another passes a check (needs Relationships). |

**Counters.** Each quest has named counters with min, max and an optional random start. In `MESSAGES` mode a counter changes when its message events match (`Killed`/`Wolf` → +1). Give a counter a `display_name` and the HUD and journal show it as an objective ("Wolves slain 3/5") whenever the active nodes have no HUD or journal text of their own (`auto_objectives`).

**Actions** run when a quest or node enters a state: set quest, node or counter states, send a message, show an alert, set an indicator, track the quest, give a quest, instantiate a scene, show or hide nodes, play audio or an animation, start or stop a spawner, call a method on nodes found by group or identity, grant a reward, and with Relationships installed, report a deed or change affinity.

**Content.** Heading, body (BBCode), icon (with count and caption), button (runs actions), link, and audio. Content is grouped by where it shows: dialogue, journal, HUD, plus the quest's offer and offer-unmet text.

**Tags.** Text can use `{QUEST}`, `{QUESTGIVER}`, `{QUESTER}`, `{#counter}` (value), `{<#counter}` / `{>#counter}` (min / max), `{:counter}` (as time), `{#other_quest:counter}`, `{TIMELIMIT}`, and generator tags such as `{TARGET}`, `{DOMAIN}` and `{REWARD}`. Any other `{Word}` is looked up in the speaker's `text_table` (pick one of `a|b` at random for dialects), then the giver's, then translated with `tr()`. All player-facing text goes through `tr()`; the translation parser adds quest text to your POT files.

**Prerequisites and time limits.** `requires_quests` lists quests that must be completed before a quest is offered. `time_limit` fails an active quest when the time runs out; the HUD shows the time remaining.

**Questers.** Any `QuestJournal` can hold quests, so NPCs can take quests too. Pass a quester id to the `Quests` helpers to read their copy: `Quests.get_quest_state("escort", "squire")`.

**Indicators.** Quests set an indicator state per character (`OFFER`, `TALK`, `INTERACT`, their disabled variants and ten custom states). Put a **QuestIndicatorManager** on a character and a **QuestIndicator** with a child per state (named `Offer`, `Talk`…); it shows the most important one.

## Nodes and resources

| Class | What it does |
| --- | --- |
| `QuestManager` | Settings, default UIs, timers, saving and the debugger connection. Emits typed signals for every quest. |
| `Quests` | Static shortcuts: give, find, read and change quests, counters and nodes; send messages. |
| `QuestDatabase`, `Quest`, `QuestNode`, `QuestCounter` | Quest data. Quests in lists are copies of the database assets. |
| `QuestList` | Holds quests for a character. Signals for added, removed and changed quests. |
| `QuestJournal` | The player's (or an NPC's) quests: tracking, abandoning, journal and HUD UIs. |
| `QuestGiver` | Offers quests in dialogue and hands them to journals. |
| `QuestIdentity` | A character's id, display name and image for messages and tags. |
| `QuestControl` | Methods to connect signals to: send messages, set states, change counters, show alerts. |
| `QuestSignalRelay` | Turns any signal into a quest message without code. |
| `QuestMessageEvents` | Emits a signal when a message arrives, or sends messages from a list. |
| `QuestDataSynchronizer` | Keeps counters in sync with your own data (`DATA_SYNC` counters). |
| `QuestSpawner`, `QuestSpawnedEntity` | Spawns scenes around markers or in a radius; started and stopped by quests. |
| `QuestIndicatorManager`, `QuestIndicator` | Quest markers over characters. |
| `QuestDialogueUI`, `QuestJournalUI`, `QuestHUD`, `QuestAlertUI` | Base classes for your own UIs. `QuestDefault*` are the built-in ones. |
| `QuestContentView` | Turns quest content into Controls; each content type can use your own scene. |
| `QuestBuilder` | Builds quests in code. |
| `QuestSerializer` | Quests and their state to and from dictionaries. |

## Messages

`Quests.send_message(message, parameter, value, sender, target)` reaches every condition and counter listening for that message. Senders and targets are ids or nodes (their `QuestIdentity` is used). Quests send their own messages too: `Quest State Changed`, `Quest Counter Changed`, `Quest Alert`, `Greet`, `Discuss Quest` and the rest in `QuestMessages`. Listen in code with `QuestMessages.add_listener()`, or connect to `QuestManager`'s signals:

```gdscript
var manager := Quests.get_manager()
manager.quest_state_changed.connect(func(quest: Quest, old_state, new_state) -> void:
	if new_state == Quest.State.SUCCESSFUL:
		print(quest.title, " done"))
```

A message condition starts listening the frame after its node activates.

## Building quests in code

```gdscript
var builder := QuestBuilder.new("Wolves", "wolves", "Wolf Problem")
builder.add_counter("wolves", 0, 0, 5, false, QuestCounter.UpdateMode.MESSAGES)
builder.add_counter_message_event("wolves", "", "Killed", "Wolf",
		QuestCounterMessageEvent.Operation.MODIFY_BY_LITERAL_VALUE, 1)
var hunt := builder.add_condition_node(builder.get_start_node(), "hunt", "Hunt wolves", QuestConditionSet.Mode.ALL)
builder.add_counter_condition(hunt, "wolves", QuestCounterCondition.CounterValueMode.AT_LEAST,
		QuestNumber.literal(5))
builder.add_success_node(hunt)
Quests.give_quest(builder.to_quest())
```

## Procedural quests

The generator makes quests from what an NPC observes.

- **Entity types** (`QuestEntityType`) describe things in the world: orcs, carrots, the player. Each has a faction, **drives** (the NPC's values, such as Compassion or Greed), **urgency functions** (how much it matters to an observer, e.g. by faction affinity or threat) and **verbs** (`QuestVerb`: kill, collect, polymorph…).
- A verb has **requirements** (facts that must hold first, such as carrying a wand), **effects** on the world, a **completion** (a message or counter), **motives** with drive values, and text for each part of the quest.
- **Domains** (`QuestDomain` with a `QuestDomainType`) are areas. Put a **QuestEntity** on things in the world; domains count the entities inside their `Area2D`/`Area3D`.
- A **QuestGeneratorEntity** next to a `QuestGiver` builds a world model from its domains, picks the most urgent fact (weighted by urgency), chooses the verb whose motive best matches its drives, plans the steps with a breadth-first search, and builds a quest with counters, conditions, content, a "return to me" step and **rewards** (`QuestXPRewardSystem`, `QuestMessageRewardSystem` or your own `QuestRewardSystem`).

```gdscript
$QuestGeneratorEntity.generated_quest.connect(func(quest: Quest) -> void: print("New: ", quest.title))
$QuestGeneratorEntity.generate_quest()
```

Planning is spread over frames (`QuestManager` generator settings) and skips world states it has already checked. Set `use_thread` to plan on a worker thread, and `random_seed` for repeatable results. With Relationships installed, set an entity type's `relationships_faction` to take affinities from the faction database instead of `QuestFaction`.

## Relationships

When the Relationships addon is installed, Quests finds it at runtime; neither addon needs the other.

- `QuestRelationshipCondition`: offer quests only to friends (`Guards` toward `Player` at least `Friendly`).
- `QuestReportDeedAction`, `QuestModifyAffinityAction`: finishing or failing a quest changes how factions feel.
- Expression conditions can call `affinity()`, `tier()` and `is_at_least_tier()`.
- The generator can score urgency and requirements by faction affinity.

## Saving

```gdscript
var data := Quests.get_manager().record_data()  # JSON-compatible Dictionary
Quests.get_manager().apply_data(data)
```

This saves every quest list (by `save_key`, the node path by default), each quest's state, node states, counters and indicators, completed quest ids, spawners, indicator managers and the generator's drive values. Quests from a database save only their state; generated quests save in full. Lists that load later, such as in another level, get their data when they enter the tree.

With the Save addon enabled, `QuestManager` registers a `quests` section by itself (`use_save_addon`), or call `Quests.register_with_save()`.

## Editor tools

- **Quests tab.** Edit a quest database as graphs: add, connect, duplicate and arrange nodes (with undo), and edit counters, conditions, actions and content from the outline. Templates and wizards create common quests and steps. The validator flags unreachable nodes, missing success nodes, duplicate ids and references to missing counters, nodes or quests.
- **Inspector.** Pickers for counter names, node ids and quest ids; inline editors for numbers and message values; summaries for generator resources.
- **Debugger.** Run the game from the editor and open **Debugger → Quests** to watch every quest list, quest, node and counter live, and change states and counters in the running game. The open quest's graph shows live node states.
- **Translations.** Quest text appears in **Project Settings → Localization → POT Generation** when you add quest resources.

## Time

Timers, cooldowns and time limits use `QuestsTime`, which follows the scene tree by default (respects `Engine.time_scale`, stops while paused). Set `QuestsTime.mode` to `REALTIME`, or `MANUAL` to drive it yourself.
