@icon("../../icons/quest_entity_type.svg")
class_name QuestEntityType
extends Resource
## An abstract kind of entity, such as an Orc or a Carrot. Quest generators plan
## with entity types rather than the [QuestEntity] nodes in the scene.
##
## An entity type holds the urgency functions, verbs (things that can be done to
## it), drive values and faction that generators use.

## Description of this entity type.
@export_multiline var description := ""
## There is only one entity of this type.
@export var is_unique := false
## The display name. If empty, the asset name is used.
@export var display_name := ""
## The plural display name. If empty, one is made from the display name.
@export var plural_display_name := ""
## May be shown in UIs.
@export var image: Texture2D
## Used to determine quest difficulty and rewards.
@export var level := 1
## The faction that this entity type belongs to.
@export var faction: QuestFaction
## The name of a faction in the Relationships addon. If set, and the addon is
## available, affinities come from it instead of [member faction].
@export var relationships_faction := ""
## Parent types from which this type inherits factions, urgency functions and verbs.
@export var parents: Array[QuestEntityType] = []
## Functions that generators use to decide how urgently they must generate a quest about this entity.
@export var urgency_functions: Array[QuestUrgencyFunction] = []
## Verbs that can be performed on this entity type.
@export var actions: Array[QuestVerb] = []
## When planning an action, the minimum count of targets to require. x is the
## total number known; y is the minimum to require.
@export var min_count_in_action: Curve = QuestCurves.linear([Vector2(0, 0), Vector2(1, 1), Vector2(2, 2), Vector2(20, 2)])
## When planning an action, the maximum count of targets to require. x is the
## total number known; y is the maximum to require.
@export var max_count_in_action: Curve = QuestCurves.linear([Vector2(0, 0), Vector2(10, 10), Vector2(20, 15)])
## Authored drive values. At runtime, use [member drive_values].
@export var original_drive_values: Array[QuestDriveValue] = []
## Multipliers for reward systems, indexed by [enum QuestRewardMultiplier.Category].
@export var reward_multipliers: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1, 1, 1, 1, 1])

## The runtime drive values, which can change during play. Initially copies of
## [member original_drive_values].
var drive_values: Array[QuestDriveValue]:
	get:
		return QuestGeneratorData.get_runtime_drive_values(self)
	set(value):
		QuestGeneratorData.set_runtime_drive_values(self, value)


func get_asset_name() -> String:
	return QuestGeneratorData.asset_name_of(self)


## The display name, falling back to the asset name.
func get_display_name() -> String:
	return display_name if not display_name.is_empty() else get_asset_name()


## The plural display name, falling back to the display name plus "s" (or "es").
func get_plural_display_name() -> String:
	if not plural_display_name.is_empty():
		return plural_display_name
	var singular := get_display_name()
	return singular + ("es" if singular.ends_with("s") else "s")


## Describes [param count] of this entity type, such as "3 Orcs" or "the Dragon".
func get_descriptor(count: int) -> String:
	if is_unique or count == 1:
		return get_display_name()
	return "%d %s" % [count, get_plural_display_name()]


## This entity type's faction, or the first faction found in its parents.
func get_faction() -> QuestFaction:
	return _get_faction(0)


func _get_faction(depth: int) -> QuestFaction:
	if faction != null:
		return faction
	if depth > 64:
		return null
	for parent in parents:
		if parent == null:
			continue
		var result := parent._get_faction(depth + 1)
		if result != null:
			return result
	return null


## The Relationships faction name of this type, or the first found in its parents.
func get_relationships_faction() -> String:
	return _get_relationships_faction(0)


func _get_relationships_faction(depth: int) -> String:
	if not relationships_faction.is_empty():
		return relationships_faction
	if depth > 64:
		return ""
	for parent in parents:
		if parent == null:
			continue
		var result := parent._get_relationships_faction(depth + 1)
		if not result.is_empty():
			return result
	return ""


## This type's urgency functions followed by those of its ancestors, without duplicates.
func get_urgency_functions() -> Array[QuestUrgencyFunction]:
	var list: Array[QuestUrgencyFunction] = urgency_functions.duplicate()
	if not parents.is_empty():
		var checked: Array[QuestEntityType] = []
		for parent in parents:
			_add_parent_urgency_functions(parent, checked, list)
	return list


func _add_parent_urgency_functions(parent: QuestEntityType, checked: Array[QuestEntityType], list: Array[QuestUrgencyFunction]) -> void:
	if parent == null or checked.has(parent):
		return
	checked.append(parent)
	for function in parent.urgency_functions:
		if not list.has(function):
			list.append(function)
	for grandparent in parent.parents:
		_add_parent_urgency_functions(grandparent, checked, list)


## All verbs that can be performed on this entity type, including inherited ones.
## Own verbs come first, then the verbs of ancestors in breadth-first order.
func get_all_actions() -> Array[QuestVerb]:
	if parents.is_empty():
		return actions
	var result: Array[QuestVerb] = []
	var processed: Array[QuestEntityType] = []
	var queue: Array[QuestEntityType] = [self]
	var head := 0
	var safeguard := 0
	while head < queue.size() and safeguard < 1000:
		safeguard += 1
		var et := queue[head]
		head += 1
		if et == null:
			continue
		processed.append(et)
		for parent in et.parents:
			if parent != null and not processed.has(parent):
				queue.append(parent)
		for action in et.actions:
			if action != null and not result.has(action):
				result.append(action)
	return result


## Looks up this type's drive value for [param drive], searching ancestors if needed.
func look_up_drive_value(drive: QuestDrive) -> QuestDriveValue:
	return _look_up_drive_value(drive, [])


func _look_up_drive_value(drive: QuestDrive, checked: Array) -> QuestDriveValue:
	if drive == null or checked.has(self):
		return null
	for dv in drive_values:
		if dv != null and dv.drive == drive:
			return dv
	if not parents.is_empty():
		checked.append(self)
		for parent in parents:
			if parent == null:
				continue
			var result := parent._look_up_drive_value(drive, checked)
			if result != null:
				return result
	return null


func get_reward_multiplier(category: QuestRewardMultiplier.Category) -> float:
	var i := int(category)
	return reward_multipliers[i] if 0 <= i and i < reward_multipliers.size() else 1.0
