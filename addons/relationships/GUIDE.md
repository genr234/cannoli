<img src="icon.svg" width="64" height="64" alt="">

# Relationships

Factions, relationships and emotions for NPCs, for Godot 4.7+.

Characters belong to factions. Factions have personality traits and feel affinity toward each other. When someone does something (a **deed**), nearby characters witness it, judge it based on who did it, who it was done to and how they feel about both, and update their opinion of the actor and their own emotional state. They remember important deeds and spread them as **gossip** to friends.

## Setup

1. Enable **Relationships** in **Project → Project Settings → Plugins**. This adds the inspector editors. The runtime classes work without it.
2. Create a **FactionDatabase** resource (**New Resource → FactionDatabase**). Add personality traits (e.g. Charity, Violence), factions, parent factions and relationships. Every database has a Player faction with ID 0.
3. Add a **FactionManager** node to your scene and assign the database.
4. Add a **FactionMember** node as a child of each character's body (a `Node2D` or `Node3D`) and pick its faction.
5. Report deeds, either in code or with a **DeedReporter** and a **DeedTemplateLibrary**.

```gdscript
# In code:
var deed := Deed.create("attack", player_member.faction_id, villager_member.faction_id, -40, 80)
FactionManager.instance.commit_deed(player_member, deed, true, 15.0)  # requires sight, 15 m radius

# With a DeedReporter on the player:
$DeedReporter.report_deed("attack", villager_member)

# Reading and changing relationships:
var affinity := villager_member.get_affinity(player_member)  # -100..100
Relationships.modify_personal_affinity("Villagers", "Player", 10)
```

Methods that take a faction accept its ID or its name.

## Concepts

**Traits.** Personality traits describe factions, deeds and things with a `Traits` node. Relationship traits describe how one faction feels about another; the first is always **Affinity**. Values range from -100 to 100.

**Inheritance.** A faction without its own relationship to another faction inherits it from parents: first its feelings toward the subject's parents, then its parents' feelings toward the subject, then its parents' feelings toward the subject's parents. Several values are averaged or summed (see `relationship_inheritance_type`). Mark a relationship non-inheritable to keep it private. A faction's affinity to itself (100) is inherited too, so factions like their sub-factions unless you say otherwise (`inherit_self_affinity`).

**Tiers.** `affinity_tiers` names bands of affinity: Hostile, Unfriendly, Neutral, Friendly and Allied by default, with your own colors and thresholds. Use them for shops, guards, quests and UI:

```gdscript
if Relationships.is_at_least_tier("Guards", "Player", "Friendly"):
    open_gate()
FactionManager.instance.tier_changed.connect(func(judge_id, subject_id, old_tier, new_tier): ...)
```

`relationship_changed` reports every change to a faction's own relationships.

**Unique members.** Tick `unique` on a member to give it its own faction at runtime, a child of its group. It inherits the group's personality and opinions, but what it experiences, and what others feel about it personally, stays its own. Save the game as usual; the unique faction is found again by the member's `save_key`. `switch_faction()` moves a unique member to another group.

**Drift.** Set `drift_fall_per_minute` and `drift_rise_per_minute` on a relationship trait to make personal values return to their baseline over time: the value in the database resource, or the inherited value. Make the rise slower than the fall for grudges that outlast favors. Relationships that drift all the way back are removed, so they inherit again.

**PAD.** Each member has a `Pad`: pleasure, arousal and dominance, plus happiness (lifetime pleasure). `pad.get_temperament()` returns a label such as Exuberant or Hostile. For your own emotion names, add an **EmotionalState** with an **EmotionModel**.

**Evaluation.** When a member witnesses or hears about a deed, its change in affinity to the actor is:

```
confidence (trust in source) × impact × affinity to the target
  + bonus for deeds whose traits match the member's faction
  + bonus when the member is aroused
```

Repeats count for less (`acclimatization_curve`), and aggressive deeds by stronger actors raise dominance more (`power_difference_curve`). Members can also take on traits of deeds done by factions they like (`impressionability`).

**Memory.** Deeds with enough effect are remembered as rumors. Short-term memory affects PAD and expires first; long-term memory is what members gossip about. Both scale with the size of the effect.

**Gossip.** Rumors lose confidence each time they're passed on (`gossip_confidence_loss`) and stop spreading after `gossip_max_hops`. Members with `gossip_exaggeration` color what they tell: a disliked actor's good deeds sound smaller and their bad deeds worse.

**Deeds.** `report_deed()` takes a magnitude to scale a template's impact, and a faction name or ID as the target when there's no particular victim:

```gdscript
$DeedReporter.report_deed("steal", merchant_member, 0.2)  # Pocketed a coin.
$DeedReporter.report_deed("steal", merchant_member, 1.0)  # Took the horse.
$DeedReporter.report_deed("burn_camp", "Bandits")
```

## Nodes and resources

| Class | What it does |
| --- | --- |
| `FactionDatabase` | Traits, presets, factions and relationships. |
| `FactionManager` | Runs the simulation on a copy of the database and delivers deeds to witnesses. |
| `FactionMember` | A character's faction, PAD and memories. Emits signals for everything that happens to it. |
| `Relationships` | Static shortcuts to the active manager. |
| `DeedReporter`, `DeedTemplateLibrary`, `DeedTemplate` | Report deeds by tag. |
| `DeedEvaluationOverrides` | Lets a member see certain deeds differently (bandits approve of robbery). |
| `GossipTrigger` | Shares rumors with friendly members who enter an `Area2D`/`Area3D`. |
| `GreetingTrigger` | Greets members who enter an area, choosing an animation by affinity and temperament. |
| `AuraTrigger` + `Traits` | Changes the PAD of members who enter an area, by how well their personality matches. |
| `DeedReactions` | Plays a reaction when the member witnesses a deed, by pleasure and temperament. |
| `GossipAnimation` | Plays an animation when the member gossips. |
| `EmotionalState`, `EmotionModel` | Names the member's emotion from PAD ranges you define. |
| `StabilizePad` | Moves PAD values back toward targets over time. |
| `CanSeeAdvanced` | Line of sight with fields of view, several ray heights and see-through layers. |
| `FactionMemberDebugger` | Shows faction, PAD and memories above a character (toggle with <kbd>`</kbd>). |
| `FactionDatabaseCsv` | Exports and imports a database as CSV files (also in the database inspector). |
| `AffinityTier` | A named band of affinity. |

Helper nodes (triggers, reactions, emotional state…) find their member automatically when they're anywhere under the same character, or you can assign `member`.

## Signals

`FactionMember` emits `pad_modified`, `deed_witnessed`, `deed_remembered`, `deed_forgotten`, `rumors_shared`, `gossiped`, `greeted` and `entered_aura`. `FactionManager` emits `relationship_changed` and `tier_changed` for the running game.

## Dialogue conditions

The `Relationships` helpers are static, so any dialogue system that evaluates GDScript expressions can use them:

```gdscript
Relationships.check("Villagers", "Player", ">=", 50)
Relationships.is_tier("Guards", "Player", "Hostile")
Relationships.get_tier_name("Merchants", "Player")  # "Friendly"
```

Faction and tier names are translated with `tr()` when shown to players: set a faction's `display_name` and add it to your translations.

## Editor tools

- **Relationships panel.** Select a faction database to open a factions × factions grid in the bottom panel. Personal values are solid, inherited ones faded. Click a cell to set a value or clear it back to inheriting.
- **Inspector.** Traits show as named sliders, with presets and "average/sum of parents" fills. Faction IDs show as names, and parents get their own editor. The database inspector has CSV import and export.
- **Debugger.** Run the game from the editor and open **Debugger → Relationships** to watch every member's PAD, memories and affinities live. The game only sends data while the tab is open.
- **Fields of view.** Select a `CanSeeAdvanced` node to see its fields of view in the 2D or 3D viewport.

## Customizing

Replace any of the member's decisions with your own `Callable`:

```gdscript
member.get_power_level = func() -> float: return stats.level
member.can_see = func(actor: FactionMember) -> bool: return perception.sees(actor.get_body())
member.evaluate_rumor = my_evaluate  # func(rumor: Rumor, source: FactionMember) -> Rumor
```

The others are `share_rumor`, `get_trust_in_source`, `get_trait_alignment`, `get_self_perceived_power_level` and `compute_dominance`.

## Saving

```gdscript
var data := FactionManager.instance.record_data()  # JSON-compatible Dictionary
FileAccess.open("user://relationships.json", FileAccess.WRITE).store_string(JSON.stringify(data))

FactionManager.instance.apply_data(JSON.parse_string(FileAccess.get_file_as_string("user://relationships.json")))
```

This saves every faction's traits, parents and relationships, and every member's faction, PAD and memories. Members are matched by `save_key` (the node path by default). Members that load later, such as those in another level, get their data when they register. Traits are saved by name, so adding, removing or reordering traits doesn't break existing saves.

## Time

Memories and cooldowns use `RelationshipsTime`. By default it follows the scene tree (it respects `Engine.time_scale` and stops while paused). Set `RelationshipsTime.mode` to `REALTIME`, or to `MANUAL` to drive it yourself.
