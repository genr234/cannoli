@tool
@icon("../icons/faction_database.svg")
class_name FactionDatabase
extends Resource
## Trait definitions, presets and factions.
##
## A database only knows about factions; it has no idea which nodes belong to
## them. Methods that take a faction accept either its ID ([int]) or its name
## ([String]).
## [br][br]
## At runtime, [FactionManager] works on a copy of its database, so changes
## made during play never touch the resource file.

## Emitted when a personality trait is set through [method set_personality_trait].
signal personality_trait_changed(faction_id: int, trait_id: int, value: float)
## Emitted when a faction's own relationship trait to another faction changes
## through this database's methods. Factions that inherit the value don't emit
## their own signal.
signal relationship_changed(judge_id: int, subject_id: int, trait_id: int, old_value: float, new_value: float)
## Emitted with [signal relationship_changed] when an affinity change crosses
## into another of the [member affinity_tiers]. A tier is null below the lowest tier.
signal tier_changed(judge_id: int, subject_id: int, old_tier: AffinityTier, new_tier: AffinityTier)

enum InheritanceType {
	## Average the parents' values.
	AVERAGE,
	## Sum the parents' values.
	SUM,
}

## Faction ID 0 is reserved for the player.
const PLAYER_FACTION_ID := 0
## Guards against cycles in the parent graph.
const MAX_RECURSION_DEPTH := 128

## Personality traits, used by factions, deeds and presets.
@export var personality_trait_definitions: Array[TraitDefinition] = []:
	set(value):
		personality_trait_definitions = value
		sync_trait_arrays()
## Relationship traits. The first is always affinity.
@export var relationship_trait_definitions: Array[TraitDefinition] = []:
	set(value):
		relationship_trait_definitions = value
		sync_trait_arrays()
@export var presets: Array[TraitPreset] = []
@export var factions: Array[Faction] = []:
	set(value):
		factions = value
		_clear_lookups()
## How [method inherit_traits_from_parents] combines the parents' traits.
@export var trait_inheritance_type := InheritanceType.AVERAGE
## How relationships inherited from several parents are combined.
@export var relationship_inheritance_type := InheritanceType.AVERAGE:
	set(value):
		relationship_inheritance_type = value
		_relationship_cache.clear()
## If true, a faction's affinity to itself (100) is inherited like any other
## relationship, so factions like their sub-factions and members of unique
## factions like their own group, unless set otherwise.
@export var inherit_self_affinity := true:
	set(value):
		inherit_self_affinity = value
		_relationship_cache.clear()
## Named bands of affinity, used by [method get_tier] and [signal tier_changed].
@export var affinity_tiers: Array[AffinityTier] = []
## The ID given to the next faction created with [method create_faction].
@export var next_id := 1

## Bumped when [method record_data]'s format changes.
const SAVE_VERSION := 2

var _id_lookup: Dictionary[int, Faction] = {}
var _name_lookup: Dictionary[String, Faction] = {}
# Resolved relationship traits by (judge, subject, trait). Holds null for "not found".
var _relationship_cache: Dictionary[Vector3i, Variant] = {}


func _init() -> void:
	# Loading a saved database replaces these defaults.
	relationship_trait_definitions = [TraitDefinition.create(Relationship.AFFINITY_TRAIT_NAME, "(Required)")]
	factions = [Faction.create(PLAYER_FACTION_ID, "Player")]
	next_id = PLAYER_FACTION_ID + 1
	affinity_tiers = [
		AffinityTier.create("Hostile", -100.0, Color("#e5534b")),
		AffinityTier.create("Unfriendly", -50.0, Color("#e09b4f")),
		AffinityTier.create("Neutral", -15.0, Color("#a0a8b8")),
		AffinityTier.create("Friendly", 15.0, Color("#8fcf6b")),
		AffinityTier.create("Allied", 50.0, Color("#4fbf7f")),
	]


## Returns an independent copy, including every faction and relationship.
func clone() -> FactionDatabase:
	return duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as FactionDatabase


## Resizes the trait arrays of factions, presets and relationships to match
## the trait definitions. Called automatically when the definitions change.
func sync_trait_arrays() -> void:
	var personality_count := personality_trait_definitions.size()
	var relationship_count := relationship_trait_definitions.size()
	for preset in presets:
		if preset != null and preset.traits.size() != personality_count:
			preset.traits.resize(personality_count)
	for faction in factions:
		if faction == null:
			continue
		if faction.traits.size() != personality_count:
			faction.traits.resize(personality_count)
		for relationship in faction.relationships:
			if relationship != null and relationship.traits.size() != relationship_count:
				relationship.traits.resize(relationship_count)


#region Factions

## Accepts a faction ID or name and returns the ID, or -1 if there's no such faction name.
func to_faction_id(faction: Variant) -> int:
	if faction is String or faction is StringName:
		return get_faction_id(faction)
	return int(faction)


## Creates a faction and returns its ID.
func create_faction(faction_name: String, faction_description := "") -> int:
	while _find_faction_by_id(next_id) != null:
		next_id += 1
	var faction := Faction.create(next_id, faction_name, faction_description)
	next_id += 1
	faction.traits.resize(personality_trait_definitions.size())
	factions.append(faction)
	_clear_lookups()
	emit_changed()
	return faction.id


## Permanently removes a faction, along with every relationship to it and
## every parent link to it.
func destroy_faction(faction: Variant) -> void:
	var target := get_faction(faction)
	if target == null:
		return
	for other in factions:
		if other != null and other != target:
			other.remove_personal_relationship(target.id)
			other.remove_direct_parent(target.id)
	factions.erase(target)
	_clear_lookups()
	emit_changed()


## Returns a faction by ID or name, or null.
func get_faction(faction: Variant) -> Faction:
	if faction is String or faction is StringName:
		return _find_faction_by_name(faction)
	return _find_faction_by_id(int(faction))


## Returns a faction's ID from its name, or -1.
func get_faction_id(faction_name: String) -> int:
	var faction := _find_faction_by_name(faction_name)
	return faction.id if faction != null else -1


func _use_lookups() -> bool:
	return not Engine.is_editor_hint()


func _find_faction_by_id(faction_id: int) -> Faction:
	if _use_lookups() and _id_lookup.has(faction_id):
		return _id_lookup[faction_id]
	for faction in factions:
		if faction != null and faction.id == faction_id:
			if _use_lookups():
				_id_lookup[faction_id] = faction
			return faction
	return null


func _find_faction_by_name(faction_name: String) -> Faction:
	if _use_lookups() and _name_lookup.has(faction_name):
		return _name_lookup[faction_name]
	for faction in factions:
		if faction != null and faction.name == faction_name:
			if _use_lookups():
				_name_lookup[faction_name] = faction
			return faction
	return null


func _clear_lookups() -> void:
	_id_lookup.clear()
	_name_lookup.clear()
	_relationship_cache.clear()


## Clears cached lookups. Call it after changing factions, parents or
## relationships directly instead of through this database's methods.
func invalidate_cache() -> void:
	_clear_lookups()

#endregion

#region Parents

## Whether a faction has another as its parent, grandparent, and so on.
func faction_has_ancestor(faction: Variant, ancestor: Variant) -> bool:
	return _has_ancestor(to_faction_id(faction), to_faction_id(ancestor), [], 0)


func _has_ancestor(faction_id: int, ancestor_id: int, visited: Array[int], depth: int) -> bool:
	if depth > MAX_RECURSION_DEPTH or visited.has(faction_id):
		return false
	visited.append(faction_id)
	var faction := get_faction(faction_id)
	if faction == null:
		return false
	if faction.has_direct_parent(ancestor_id):
		return true
	for parent_id in faction.parents:
		if _has_ancestor(parent_id, ancestor_id, visited, depth + 1):
			return true
	return false


func faction_has_direct_parent(faction: Variant, parent: Variant) -> bool:
	var target := get_faction(faction)
	return target != null and target.has_direct_parent(to_faction_id(parent))


func add_faction_parent(faction: Variant, parent: Variant) -> void:
	var target := get_faction(faction)
	if target != null:
		target.add_direct_parent(to_faction_id(parent))
		_relationship_cache.clear()


## Removes a direct parent. If [param inherit_relationships] is true, the
## faction keeps copies of the parent's relationships that it doesn't already
## have itself.
func remove_faction_parent(faction: Variant, parent: Variant, inherit_relationships: bool) -> void:
	var target := get_faction(faction)
	var parent_faction := get_faction(parent)
	if target == null or parent_faction == null or not target.has_direct_parent(parent_faction.id):
		return
	target.remove_direct_parent(parent_faction.id)
	_relationship_cache.clear()
	if inherit_relationships:
		for relationship in parent_faction.relationships:
			if relationship != null and not target.has_personal_relationship(relationship.faction_id):
				target.relationships.append(Relationship.create(relationship.faction_id, relationship.traits))

#endregion

#region Personality traits

## Returns a personality trait's index by name, or -1.
func get_personality_trait_id(trait_name: String) -> int:
	for i in personality_trait_definitions.size():
		if personality_trait_definitions[i] != null and personality_trait_definitions[i].name == trait_name:
			return i
	return -1


## Accepts a personality trait index or name and returns the index.
func to_personality_trait_id(trait_ref: Variant) -> int:
	if trait_ref is String or trait_ref is StringName:
		return get_personality_trait_id(trait_ref)
	return int(trait_ref)


func get_personality_trait(faction: Variant, trait_ref: Variant) -> float:
	var target := get_faction(faction)
	var trait_id := to_personality_trait_id(trait_ref)
	if target != null and 0 <= trait_id and trait_id < target.traits.size():
		return target.traits[trait_id]
	return 0.0


## Sets a personality trait, clamped to the trait definition's range.
func set_personality_trait(faction: Variant, trait_ref: Variant, value: float) -> void:
	var target := get_faction(faction)
	var trait_id := to_personality_trait_id(trait_ref)
	if target == null or trait_id < 0 or trait_id >= target.traits.size():
		return
	var clamped := value
	if trait_id < personality_trait_definitions.size():
		var definition := personality_trait_definitions[trait_id]
		clamped = clampf(value, definition.min_value, definition.max_value)
	target.traits[trait_id] = clamped
	personality_trait_changed.emit(target.id, trait_id, clamped)


## Replaces a faction's traits with its direct parents' traits, combined using
## [param inheritance_type] (or [member trait_inheritance_type] if -1).
func inherit_traits_from_parents(faction: Variant, inheritance_type := -1) -> void:
	var target := get_faction(faction)
	if target == null or target.parents.is_empty():
		return
	var mode: int = trait_inheritance_type if inheritance_type < 0 else inheritance_type
	var total := PackedFloat32Array()
	total.resize(target.traits.size())
	var count := 0
	for parent_id in target.parents:
		var parent := get_faction(parent_id)
		if parent == null:
			continue
		count += 1
		for t in mini(parent.traits.size(), total.size()):
			total[t] += parent.traits[t]
	if count == 0:
		return
	for t in total.size():
		total[t] = clampf(total[t] if mode == InheritanceType.SUM else total[t] / count, -100.0, 100.0)
	target.traits = total

#endregion

#region Relationships

## Returns a relationship trait's index by name, or -1.
func get_relationship_trait_id(trait_name: String) -> int:
	for i in relationship_trait_definitions.size():
		if relationship_trait_definitions[i] != null and relationship_trait_definitions[i].name == trait_name:
			return i
	return -1


## Accepts a relationship trait index or name and returns the index.
func to_relationship_trait_id(trait_ref: Variant) -> int:
	if trait_ref is String or trait_ref is StringName:
		return get_relationship_trait_id(trait_ref)
	return int(trait_ref)


## Returns the judge's own relationship to the subject, ignoring parents, or null.
func find_personal_relationship(judge: Variant, subject: Variant) -> Relationship:
	var judge_faction := get_faction(judge)
	return judge_faction.find_personal_relationship(to_faction_id(subject)) if judge_faction != null else null


## Returns the judge's own relationship trait to the subject, ignoring parents,
## or null if the judge has no personal relationship. A faction's affinity to
## itself is always 100.
func find_personal_relationship_trait(judge: Variant, subject: Variant, trait_ref: Variant) -> Variant:
	var judge_id := to_faction_id(judge)
	var subject_id := to_faction_id(subject)
	var trait_id := to_relationship_trait_id(trait_ref)
	var relationship := find_personal_relationship(judge_id, subject_id)
	if relationship != null:
		return relationship.get_trait(trait_id)
	if judge_id == subject_id and trait_id == Relationship.AFFINITY_TRAIT_INDEX:
		return 100.0
	return null


## Returns the judge's relationship trait to the subject, including values
## inherited through either faction's parents, or null if none is defined.
func find_relationship_trait(judge: Variant, subject: Variant, trait_ref: Variant) -> Variant:
	return _resolve(to_faction_id(judge), to_faction_id(subject), to_relationship_trait_id(trait_ref))


func _resolve(judge_id: int, subject_id: int, trait_id: int) -> Variant:
	if not _use_lookups():
		return _find_relationship_trait(judge_id, subject_id, trait_id, 0, false)
	var key := Vector3i(judge_id, subject_id, trait_id)
	if not _relationship_cache.has(key):
		_relationship_cache[key] = _find_relationship_trait(judge_id, subject_id, trait_id, 0, false)
	return _relationship_cache[key]


## The value the judge would have for the subject without its own personal
## relationship: inherited through parents, or the default.
func get_inherited_relationship_trait(judge: Variant, subject: Variant, trait_ref: Variant) -> float:
	var judge_id := to_faction_id(judge)
	var subject_id := to_faction_id(subject)
	var trait_id := to_relationship_trait_id(trait_ref)
	var value: Variant = _find_inherited(judge_id, subject_id, trait_id, 0)
	return value if value != null else Relationship.get_default_value(judge_id, subject_id, trait_id)


func _find_relationship_trait(judge_id: int, subject_id: int, trait_id: int, depth: int, require_inheritable: bool) -> Variant:
	if depth > MAX_RECURSION_DEPTH:
		push_warning("Relationships: find_relationship_trait exceeded the max parent search depth.")
		return null
	var judge := get_faction(judge_id)
	var subject := get_faction(subject_id)
	if judge == null or subject == null:
		return null

	# The judge's own relationship to the subject:
	var relationship := judge.find_personal_relationship(subject_id)
	if relationship != null and (relationship.inheritable or not require_inheritable):
		return relationship.get_trait(trait_id)
	if judge == subject:
		# Reached through a parent: a faction's affinity to itself.
		if require_inheritable and inherit_self_affinity and trait_id == Relationship.AFFINITY_TRAIT_INDEX:
			return 100.0
		return null
	return _find_inherited(judge_id, subject_id, trait_id, depth)


# The parent-based part of the relationship search.
func _find_inherited(judge_id: int, subject_id: int, trait_id: int, depth: int) -> Variant:
	var judge := get_faction(judge_id)
	var subject := get_faction(subject_id)
	if judge == null or subject == null or judge == subject:
		return null

	# The judge's relationships to the subject's parents:
	var found := 0
	var total := 0.0
	for subject_parent_id in subject.parents:
		var value: Variant = _find_relationship_trait(judge_id, subject_parent_id, trait_id, depth + 1, true)
		if value != null:
			found += 1
			total += value
	if found > 0:
		return _combine_inherited(total, found)

	# The judge's parents' relationships to the subject:
	for judge_parent_id in judge.parents:
		var value: Variant = _find_relationship_trait(judge_parent_id, subject_id, trait_id, depth + 1, true)
		if value != null:
			found += 1
			total += value
	if found > 0:
		return _combine_inherited(total, found)

	# The judge's parents' relationships to the subject's parents:
	for judge_parent_id in judge.parents:
		for subject_parent_id in subject.parents:
			var value: Variant = _find_relationship_trait(judge_parent_id, subject_parent_id, trait_id, depth + 1, true)
			if value != null:
				found += 1
				total += value
	if found > 0:
		return _combine_inherited(total, found)
	return null


func _combine_inherited(total: float, found: int) -> float:
	var value := total if relationship_inheritance_type == InheritanceType.SUM or found == 0 else total / found
	return clampf(value, -100.0, 100.0)


## Returns the judge's relationship trait to the subject, including inherited
## values, or the default value if none is defined.
func get_relationship_trait(judge: Variant, subject: Variant, trait_ref: Variant) -> float:
	var judge_id := to_faction_id(judge)
	var subject_id := to_faction_id(subject)
	var trait_id := to_relationship_trait_id(trait_ref)
	var value: Variant = _resolve(judge_id, subject_id, trait_id)
	return value if value != null else Relationship.get_default_value(judge_id, subject_id, trait_id)


## Sets the judge's own relationship trait to the subject, clamped to the trait
## definition's range. If the judge has [member Faction.percent_judge_parents],
## its relationships to the subject's parents change too.
func set_personal_relationship_trait(judge: Variant, subject: Variant, trait_ref: Variant, value: float) -> void:
	var judge_faction := get_faction(judge)
	if judge_faction == null:
		return
	var subject_id := to_faction_id(subject)
	var trait_id := to_relationship_trait_id(trait_ref)
	var clamped := value
	if 0 <= trait_id and trait_id < relationship_trait_definitions.size():
		var definition := relationship_trait_definitions[trait_id]
		clamped = clampf(value, definition.min_value, definition.max_value)
	if is_zero_approx(judge_faction.percent_judge_parents):
		_write_relationship_trait(judge_faction, subject_id, trait_id, clamped)
		return
	var change := clamped - get_relationship_trait(judge_faction.id, subject_id, trait_id)
	var change_for_parents := change * judge_faction.percent_judge_parents / 100.0
	_write_relationship_trait(judge_faction, subject_id, trait_id, clamped)
	var subject_faction := get_faction(subject_id)
	if subject_faction != null:
		for parent_id in subject_faction.parents:
			modify_personal_relationship_trait(judge_faction.id, parent_id, trait_id, change_for_parents)


# Writes a personal relationship trait and emits the change signals.
func _write_relationship_trait(judge_faction: Faction, subject_id: int, trait_id: int, value: float) -> void:
	var old_value := get_relationship_trait(judge_faction.id, subject_id, trait_id)
	judge_faction.set_personal_relationship_trait(subject_id, trait_id, value, relationship_trait_definitions.size())
	_relationship_cache.clear()
	if is_equal_approx(old_value, value):
		return
	relationship_changed.emit(judge_faction.id, subject_id, trait_id, old_value, value)
	if trait_id == Relationship.AFFINITY_TRAIT_INDEX:
		var old_tier := tier_for_affinity(old_value)
		var new_tier := tier_for_affinity(value)
		if old_tier != new_tier:
			tier_changed.emit(judge_faction.id, subject_id, old_tier, new_tier)


## Removes the judge's own relationship to the subject, so it inherits again.
func remove_personal_relationship(judge: Variant, subject: Variant) -> void:
	var judge_faction := get_faction(judge)
	var subject_id := to_faction_id(subject)
	if judge_faction == null or not judge_faction.has_personal_relationship(subject_id):
		return
	var old_values := PackedFloat32Array()
	for trait_id in relationship_trait_definitions.size():
		old_values.append(get_relationship_trait(judge_faction.id, subject_id, trait_id))
	judge_faction.remove_personal_relationship(subject_id)
	_relationship_cache.clear()
	for trait_id in old_values.size():
		var new_value := get_relationship_trait(judge_faction.id, subject_id, trait_id)
		if not is_equal_approx(old_values[trait_id], new_value):
			relationship_changed.emit(judge_faction.id, subject_id, trait_id, old_values[trait_id], new_value)
			if trait_id == Relationship.AFFINITY_TRAIT_INDEX and tier_for_affinity(old_values[trait_id]) != tier_for_affinity(new_value):
				tier_changed.emit(judge_faction.id, subject_id, tier_for_affinity(old_values[trait_id]), tier_for_affinity(new_value))


## Adds [param change] to the judge's relationship trait to the subject.
func modify_personal_relationship_trait(judge: Variant, subject: Variant, trait_ref: Variant, change: float) -> void:
	var current := get_relationship_trait(judge, subject, trait_ref)
	set_personal_relationship_trait(judge, subject, trait_ref, current + change)


func set_personal_relationship_inheritable(judge: Variant, subject: Variant, inheritable: bool) -> void:
	var judge_faction := get_faction(judge)
	if judge_faction != null:
		judge_faction.set_personal_relationship_inheritable(to_faction_id(subject), inheritable)
		_relationship_cache.clear()


## If the judge has a personal relationship to the subject and the other
## faction doesn't, gives the other faction one, scaled by the other's
## affinity to the judge.
func share_relationship_traits(judge: Variant, other: Variant, subject: Variant) -> void:
	var judge_id := to_faction_id(judge)
	var other_id := to_faction_id(other)
	var subject_id := to_faction_id(subject)
	var relationship := find_personal_relationship(judge_id, subject_id)
	if relationship == null or find_personal_affinity(other_id, subject_id) != null:
		return
	var modifier := get_affinity(other_id, judge_id) / 100.0
	for trait_id in relationship_trait_definitions.size():
		set_personal_relationship_trait(other_id, subject_id, trait_id, relationship.get_trait(trait_id) * modifier)


## Same as [method share_relationship_traits].
func share_affinity(judge: Variant, other: Variant, subject: Variant) -> void:
	share_relationship_traits(judge, other, subject)


## The judge's own affinity to the subject, ignoring parents, or null.
func find_personal_affinity(judge: Variant, subject: Variant) -> Variant:
	return find_personal_relationship_trait(judge, subject, Relationship.AFFINITY_TRAIT_INDEX)


## The judge's affinity to the subject, including inherited values, or null.
func find_affinity(judge: Variant, subject: Variant) -> Variant:
	return find_relationship_trait(judge, subject, Relationship.AFFINITY_TRAIT_INDEX)


## The judge's affinity to the subject in [-100, 100], including inherited values.
func get_affinity(judge: Variant, subject: Variant) -> float:
	return get_relationship_trait(judge, subject, Relationship.AFFINITY_TRAIT_INDEX)


func set_personal_affinity(judge: Variant, subject: Variant, affinity: float) -> void:
	set_personal_relationship_trait(judge, subject, Relationship.AFFINITY_TRAIT_INDEX, affinity)


func modify_personal_affinity(judge: Variant, subject: Variant, change: float) -> void:
	modify_personal_relationship_trait(judge, subject, Relationship.AFFINITY_TRAIT_INDEX, change)

#endregion

#region Tiers

## The tier an affinity value falls in, or null if it's below every tier.
func tier_for_affinity(affinity: float) -> AffinityTier:
	var best: AffinityTier = null
	for tier in affinity_tiers:
		if tier != null and affinity >= tier.min_affinity and (best == null or tier.min_affinity > best.min_affinity):
			best = tier
	return best


## The judge's tier toward the subject, or null.
func get_tier(judge: Variant, subject: Variant) -> AffinityTier:
	return tier_for_affinity(get_affinity(judge, subject))


## The name of the judge's tier toward the subject, or an empty string.
func get_tier_name(judge: Variant, subject: Variant) -> String:
	var tier := get_tier(judge, subject)
	return tier.name if tier != null else ""


## Returns a tier by name, or null.
func find_tier(tier_name: String) -> AffinityTier:
	for tier in affinity_tiers:
		if tier != null and tier.name == tier_name:
			return tier
	return null


## Whether the judge's affinity to the subject reaches the named tier or a higher one.
func is_at_least_tier(judge: Variant, subject: Variant, tier_name: String) -> bool:
	var tier := find_tier(tier_name)
	return tier != null and get_affinity(judge, subject) >= tier.min_affinity

#endregion

#region Drift

## Moves personal relationship traits back toward their baselines, by each
## trait definition's drift rates. The baseline is [param baseline]'s
## personal value if it has one, otherwise the inherited value. Personal
## relationships that end up equal to what would be inherited are removed.
## [FactionManager] calls this; see [member FactionManager.drift_interval].
func drift_relationships(seconds: float, baseline: FactionDatabase) -> void:
	var drifting: Array[int] = []
	for trait_id in relationship_trait_definitions.size():
		var definition := relationship_trait_definitions[trait_id]
		if definition != null and (definition.drift_fall_per_minute > 0.0 or definition.drift_rise_per_minute > 0.0):
			drifting.append(trait_id)
	if drifting.is_empty():
		return
	for judge: Faction in factions.duplicate():
		if judge == null:
			continue
		for relationship: Relationship in judge.relationships.duplicate():
			if relationship == null:
				continue
			var subject_id := relationship.faction_id
			var original := baseline.find_personal_relationship(judge.id, subject_id) if baseline != null else null
			var settled := original == null
			for trait_id in relationship_trait_definitions.size():
				var inherited := get_inherited_relationship_trait(judge.id, subject_id, trait_id)
				var target := original.get_trait(trait_id) if original != null else inherited
				var current := relationship.get_trait(trait_id)
				if drifting.has(trait_id) and not is_equal_approx(current, target):
					var definition := relationship_trait_definitions[trait_id]
					var rate := definition.drift_fall_per_minute if current > target else definition.drift_rise_per_minute
					current = move_toward(current, target, rate * seconds / 60.0)
					_write_relationship_trait(judge, subject_id, trait_id, current)
				settled = settled and is_equal_approx(current, inherited)
			if settled:
				judge.remove_personal_relationship(subject_id)
				_relationship_cache.clear()

#endregion

#region Saving

## Records every faction's traits, parents and relationships in a
## JSON-compatible dictionary. Trait definitions and presets aren't included.
## Trait values are keyed by trait name, so saves survive adding, removing
## or reordering traits.
func record_data() -> Dictionary:
	var faction_data := []
	for faction in factions:
		if faction == null:
			continue
		var relationship_data := []
		for relationship in faction.relationships:
			if relationship != null:
				relationship_data.append({
					"faction_id": relationship.faction_id,
					"inheritable": relationship.inheritable,
					"traits": traits_to_dictionary(relationship.traits, relationship_trait_definitions),
				})
		var entry := {
			"id": faction.id,
			"name": faction.name,
			"traits": traits_to_dictionary(faction.traits, personality_trait_definitions),
			"parents": Array(faction.parents),
			"relationships": relationship_data,
		}
		if not faction.owner_key.is_empty():
			entry["owner_key"] = faction.owner_key
		faction_data.append(entry)
	return {"version": SAVE_VERSION, "next_id": next_id, "factions": faction_data}


## Restores data from [method record_data]. Factions in the data that the
## database doesn't have are created. Also reads saves from version 1, which
## stored trait values as arrays.
func apply_data(data: Dictionary) -> void:
	var saved_owner_keys: Dictionary[String, int] = {}
	for entry: Dictionary in data.get("factions", []):
		var faction_id := int(entry.get("id", -1))
		var faction := get_faction(faction_id)
		if faction == null:
			faction = Faction.create(faction_id, str(entry.get("name", "")))
			factions.append(faction)
			_clear_lookups()
		elif entry.has("name") and faction.name != str(entry.name):
			faction.name = str(entry.name)
		faction.owner_key = str(entry.get("owner_key", ""))
		if not faction.owner_key.is_empty():
			saved_owner_keys[faction.owner_key] = faction.id
		faction.traits = traits_from_data(entry.get("traits", []), personality_trait_definitions)
		faction.parents = PackedInt32Array(entry.get("parents", []))
		var relationships: Array[Relationship] = []
		for relationship_entry: Dictionary in entry.get("relationships", []):
			relationships.append(Relationship.create(
					int(relationship_entry.get("faction_id", 0)),
					traits_from_data(relationship_entry.get("traits", []), relationship_trait_definitions),
					bool(relationship_entry.get("inheritable", true))))
		faction.relationships = relationships
	# A unique member may have created a new faction before the save was
	# applied. The saved one wins.
	for faction: Faction in factions.duplicate():
		if faction != null and saved_owner_keys.has(faction.owner_key) and saved_owner_keys[faction.owner_key] != faction.id:
			destroy_faction(faction.id)
	next_id = maxi(next_id, int(data.get("next_id", next_id)))
	_clear_lookups()
	emit_changed()


## Converts trait values to a dictionary keyed by trait name.
static func traits_to_dictionary(values: PackedFloat32Array, definitions: Array[TraitDefinition]) -> Dictionary:
	var result := {}
	for i in mini(values.size(), definitions.size()):
		if definitions[i] != null:
			result[definitions[i].name] = values[i]
	return result


## Converts saved trait values (a dictionary keyed by name, or an array from
## older saves) to an array matching [param definitions].
static func traits_from_data(data: Variant, definitions: Array[TraitDefinition]) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(definitions.size())
	if data is Dictionary:
		for i in definitions.size():
			if definitions[i] != null:
				result[i] = float(data.get(definitions[i].name, 0.0))
	elif data is Array:
		for i in mini(data.size(), result.size()):
			result[i] = float(data[i])
	return result

#endregion
