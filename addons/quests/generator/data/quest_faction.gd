class_name QuestFaction
extends Resource
## A set of relationships to other factions. Quest generators use faction
## affinities to decide how urgent an entity is.
##
## When the Relationships addon is installed, an entity type can instead name a
## faction from that addon in [member QuestEntityType.relationships_faction].

@export var relationships: Array[QuestFactionRelationship] = []


## Returns this faction's affinity for [param other], or 0 if there is no relationship.
func get_affinity(other: QuestFaction) -> float:
	for relationship in relationships:
		if relationship == null:
			continue
		if relationship.faction == other:
			return relationship.affinity
	return 0.0


## Sets this faction's affinity for [param other], adding a relationship if needed.
func set_affinity(other: QuestFaction, affinity: float) -> void:
	for relationship in relationships:
		if relationship != null and relationship.faction == other:
			relationship.affinity = affinity
			return
	relationships.append(QuestFactionRelationship.create(other, affinity))
