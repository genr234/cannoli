class_name QuestFactionRelationship
extends Resource
## How one [QuestFaction] feels about another.

## The other faction for whom this faction holds a negative or positive feeling.
@export var faction: QuestFaction
## The degree of negative or positive feeling for the faction, in the range [-100,+100].
@export_range(-100.0, 100.0) var affinity := 0.0


static func create(p_faction: QuestFaction, p_affinity: float) -> QuestFactionRelationship:
	var r := QuestFactionRelationship.new()
	r.faction = p_faction
	r.affinity = p_affinity
	return r
