# Relationships

Factions, affinity, emotions, memories and gossip for NPCs in **Godot 4.7+**.

[![Download Relationships](download.svg)](https://github.com/genr234/cannoli/releases/download/latest-build/relationships.zip)

[Full guide →](GUIDE.md) · [Cannoli →](https://github.com/genr234/cannoli)

## Install

Extract the ZIP into your project and enable **Relationships** in **Project → Project Settings → Plugins**. Runtime classes also work without the editor plugin.

## Get started

1. Create a **FactionDatabase** with traits, factions and relationships.
2. Add a **FactionManager** to your scene and assign the database.
3. Add a **FactionMember** beneath each character and choose its faction.
4. Add a **DeedReporter** with deed templates to report what happens:

```gdscript
$DeedReporter.report_deed("attack", villager_member)
var affinity := villager_member.get_affinity(player_member)
Relationships.modify_personal_affinity("Villagers", "Player", 10)
```

Witnesses judge deeds, update their opinions and emotions, remember significant events and share rumors with friends. Faction arguments accept IDs or names.

| Feature | Details |
| --- | --- |
| Factions | Inheritance, personal opinions, affinity tiers and drift |
| NPCs | Personality traits, PAD emotions, memories and gossip |
| Tools | Relationship grid, CSV import/export and live debugger |

See the guide for [concepts](GUIDE.md#concepts), [helper nodes](GUIDE.md#nodes-and-resources), [dialogue conditions](GUIDE.md#dialogue-conditions) and [saving](GUIDE.md#saving).

[MIT](LICENSE).
