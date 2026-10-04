@tool
@icon("../icons/traits.svg")
class_name Traits
extends Node
## Gives personality traits to something that isn't a faction member, such as
## an item, a location or an [AuraTrigger].
##
## Also provides helpers for working with trait arrays.

## Only used to name the traits in the inspector and by [method get_trait].
## If empty, the scene's [FactionManager] database is used.
@export var faction_database: FactionDatabase
## Personality trait values, one per personality trait definition.
@export var traits := PackedFloat32Array()


## Returns the database used to look up trait names.
func get_database() -> FactionDatabase:
	if faction_database != null:
		return faction_database
	var manager := FactionManager.find_for(self)
	return manager.get_database() if manager != null else null


## Returns a trait value by name or index.
func get_trait(trait_ref: Variant) -> float:
	var trait_id := int(trait_ref)
	if trait_ref is String or trait_ref is StringName:
		var database := get_database()
		trait_id = database.get_personality_trait_id(trait_ref) if database != null else -1
	return traits[trait_id] if 0 <= trait_id and trait_id < traits.size() else 0.0


## How closely two sets of trait values match, from 0 (opposites) to 1
## (identical). Only the overlapping part of the arrays is compared.
static func alignment(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var length := mini(a.size(), b.size())
	if length == 0:
		return 0.0
	var overlap := 0.0
	for i in length:
		overlap += 1.0 - absf(a[i] - b[i]) / 200.0
	return overlap / length
