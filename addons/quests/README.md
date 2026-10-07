# Quests

Quest graphs, procedural generation, dialogue, journals and HUDs for **Godot 4.7+**.

[![Download Quests](download.svg)](https://github.com/genr234/cannoli/releases/download/latest-build/quests.zip)

[Full guide →](GUIDE.md) · [Cannoli →](https://github.com/genr234/cannoli)

## Install

Extract the ZIP into your project and enable **Quests** in **Project → Project Settings → Plugins**. Runtime classes also work without the editor plugin.

## Get started

1. Create a **QuestDatabase** and build quests in the **Quests** tab, or choose a template.
2. Add a **QuestManager** to your main scene and assign the database. Instance `res://addons/quests/ui/quest_ui.tscn` for the default UIs.
3. Add a **QuestJournal** to the player, a **QuestGiver** to NPCs, and a **QuestIdentity** to each character. Assign the giver's quests.
4. Send messages from gameplay:

```gdscript
Quests.send_message("Killed", "Wolf")
$QuestGiver.start_dialogue(player)
var state := Quests.get_quest_state("pesky_rabbits")
```

Press **J** to toggle the default journal. Quest nodes wait for conditions, run actions and activate their children; success or failure nodes end the quest.

| Feature | Details |
| --- | --- |
| Authoring | Graphs, templates, counters, conditions and actions |
| Generation | NPC drives, world models, planning and rewards |
| Tools | Built-in UIs, validation, translations and live debugger |

Save and Relationships integrate automatically when installed; both are optional.

See the guide for [messages](GUIDE.md#messages), [code-built quests](GUIDE.md#building-quests-in-code), [generation](GUIDE.md#procedural-quests) and [saving](GUIDE.md#saving).

[MIT](LICENSE).
