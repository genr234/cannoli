class_name QuestAffinity
extends RefCounted
## Looks up how one entity type feels about another. Uses [QuestFaction] unless
## both entity types name a faction from the Relationships addon and the
## [code]QuestsRelationships[/code] bridge reports that addon as available.
##
## While a plan is computed on a worker thread, the Relationships addon (which
## lives in the scene tree) can't be queried. The planner instead fills
## [member QuestWorldModel.affinity_cache] on the main thread and lookups read
## from that.

const BRIDGE_PATH := "res://addons/quests/integrations/relationships_bridge.gd"

static var _bridge: GDScript
static var _bridge_checked := false


## True if the Relationships bridge exists and reports the addon as available.
static func is_relationships_available() -> bool:
	if not _bridge_checked:
		_bridge_checked = true
		if ResourceLoader.exists(BRIDGE_PATH):
			_bridge = load(BRIDGE_PATH) as GDScript
	if _bridge == null:
		return false
	return bool(_bridge.call(&"is_available")) and bool(_bridge.call(&"has_manager"))


## Clears the cached bridge lookup. Call after enabling or disabling the Relationships addon.
static func reset_bridge_cache() -> void:
	_bridge = null
	_bridge_checked = false


## Whether this lookup should use the Relationships addon.
static func uses_relationships(judge: QuestEntityType, subject: QuestEntityType, world_model: QuestWorldModel = null) -> bool:
	if judge == null or subject == null:
		return false
	if judge.get_relationships_faction().is_empty() or subject.get_relationships_faction().is_empty():
		return false
	if world_model != null and world_model.use_affinity_cache:
		return true
	return is_relationships_available()


## Returns the affinity, in [-100,+100], that [param judge] has for [param subject].
## Logs an error and returns 0 if a faction is missing.
static func get_affinity(judge: QuestEntityType, subject: QuestEntityType, world_model: QuestWorldModel = null) -> float:
	if judge == null or subject == null:
		return 0.0
	if uses_relationships(judge, subject, world_model):
		var key := judge.get_relationships_faction() + "|" + subject.get_relationships_faction()
		if world_model != null and world_model.use_affinity_cache:
			return float(world_model.affinity_cache.get(key, 0.0))
		return float(_bridge.call(&"get_affinity", judge.get_relationships_faction(), subject.get_relationships_faction()))
	var judge_faction := judge.get_faction()
	var subject_faction := subject.get_faction()
	if judge_faction == null:
		push_error("Quests: %s faction is null. Do you need to assign a faction?" % judge.get_asset_name())
		return 0.0
	if subject_faction == null:
		push_error("Quests: %s faction is null. Do you need to assign a faction?" % subject.get_asset_name())
		return 0.0
	return judge_faction.get_affinity(subject_faction)


## Fills [param cache] with affinities between every pair of the given entity
## types that use the Relationships addon. Must be called on the main thread.
static func fill_cache(types: Array, cache: Dictionary) -> void:
	if not is_relationships_available():
		return
	var names: Array[String] = []
	for t in types:
		var et := t as QuestEntityType
		if et == null:
			continue
		var n := et.get_relationships_faction()
		if not n.is_empty() and not names.has(n):
			names.append(n)
	for judge_name in names:
		for subject_name in names:
			cache[judge_name + "|" + subject_name] = float(_bridge.call(&"get_affinity", judge_name, subject_name))
