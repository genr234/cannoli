@tool
class_name Relationship
extends Resource
## A faction's feelings toward another faction: a set of relationship trait
## values whose first trait is always affinity.

const AFFINITY_TRAIT_NAME := "Affinity"
const AFFINITY_TRAIT_INDEX := 0

## The faction this relationship is directed to.
@export var faction_id := 0
## Whether child factions inherit this relationship.
@export var inheritable := true
## Relationship trait values. The first is always affinity.
@export var traits := PackedFloat32Array()

var affinity: float:
	get:
		return traits[0] if traits.size() > 0 else 0.0
	set(value):
		if traits.size() > 0:
			traits[0] = value


static func create(to_faction_id: int, trait_values: PackedFloat32Array, is_inheritable := true) -> Relationship:
	var relationship := Relationship.new()
	relationship.faction_id = to_faction_id
	relationship.inheritable = is_inheritable
	relationship.traits = trait_values.duplicate()
	return relationship


func get_trait(index: int) -> float:
	return traits[index] if 0 <= index and index < traits.size() else 0.0


func set_trait(index: int, value: float) -> void:
	if 0 <= index and index < traits.size():
		traits[index] = value
		emit_changed()


## The value used when no relationship is defined: 100 for a faction's affinity
## to itself, otherwise 0.
static func get_default_value(judge_faction_id: int, subject_faction_id: int, trait_id: int) -> float:
	return 100.0 if judge_faction_id == subject_faction_id and trait_id == AFFINITY_TRAIT_INDEX else 0.0
