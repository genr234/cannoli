@tool
class_name Faction
extends Resource
## A faction record in a [FactionDatabase]. A faction only knows other
## factions by ID, through its parents and relationships.

## The faction's unique ID. ID 0 is reserved for the player.
@export var id := 0
@export var name := "":
	set(value):
		name = value
		resource_name = value
		emit_changed()
## Shown to players instead of [member name] if set. Translated with [method Object.tr].
@export var display_name := ""
@export_multiline var description := ""
## Used by the debugger and editor to tell factions apart.
@export var color := Color.WHITE
## Direct parent faction IDs. Parents may have parents of their own.
@export var parents := PackedInt32Array()
## Personality trait values, one per personality trait definition.
@export var traits := PackedFloat32Array()
## How this faction feels about other factions.
@export var relationships: Array[Relationship] = []
## If nonzero, setting a relationship to a subject also changes this faction's
## relationships to the subject's parents by this percent of the change.
@export_range(-100, 100) var percent_judge_parents := 0.0
## Set on factions created for unique [FactionMember]s: the member's save key.
@export var owner_key := ""


static func create(faction_id: int, faction_name: String, faction_description := "") -> Faction:
	var faction := Faction.new()
	faction.id = faction_id
	faction.name = faction_name
	faction.description = faction_description
	return faction


## The translated [member display_name], or [member name] if it's empty.
func get_display_name() -> String:
	return tr(display_name if not display_name.is_empty() else name)


func has_direct_parent(parent_id: int) -> bool:
	return parents.has(parent_id)


func add_direct_parent(parent_id: int) -> void:
	if not has_direct_parent(parent_id):
		parents.append(parent_id)
		emit_changed()


func remove_direct_parent(parent_id: int) -> void:
	var index := parents.find(parent_id)
	if index >= 0:
		parents.remove_at(index)
		emit_changed()


## Returns this faction's own relationship to another faction, or null.
func find_personal_relationship(faction_id: int) -> Relationship:
	for relationship in relationships:
		if relationship != null and relationship.faction_id == faction_id:
			return relationship
	return null


func has_personal_relationship(faction_id: int) -> bool:
	return find_personal_relationship(faction_id) != null


func remove_personal_relationship(faction_id: int) -> void:
	relationships = relationships.filter(func(r: Relationship) -> bool: return r == null or r.faction_id != faction_id)
	emit_changed()


## Returns a personal relationship trait, or the default value if this faction
## has no personal relationship to the other faction.
func get_personal_relationship_trait(faction_id: int, trait_id: int) -> float:
	var relationship := find_personal_relationship(faction_id)
	if relationship != null:
		return relationship.get_trait(trait_id)
	return Relationship.get_default_value(id, faction_id, trait_id)


## Sets a personal relationship trait, creating the relationship if needed.
## [param trait_count] sizes the traits of a new relationship.
func set_personal_relationship_trait(faction_id: int, trait_id: int, value: float, trait_count: int) -> void:
	var relationship := find_personal_relationship(faction_id)
	if relationship == null:
		var values := PackedFloat32Array()
		values.resize(trait_count)
		relationship = Relationship.create(faction_id, values)
		relationships.append(relationship)
	relationship.set_trait(trait_id, value)
	emit_changed()


func set_personal_relationship_inheritable(faction_id: int, inheritable: bool) -> void:
	var relationship := find_personal_relationship(faction_id)
	if relationship != null:
		relationship.inheritable = inheritable


func get_personal_affinity(faction_id: int) -> float:
	return get_personal_relationship_trait(faction_id, Relationship.AFFINITY_TRAIT_INDEX)


func set_personal_affinity(faction_id: int, affinity: float, trait_count: int) -> void:
	set_personal_relationship_trait(faction_id, Relationship.AFFINITY_TRAIT_INDEX, affinity, trait_count)
