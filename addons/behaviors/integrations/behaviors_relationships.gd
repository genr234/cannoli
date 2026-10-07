@tool
class_name BehaviorsRelationships
extends RefCounted
## Optional bridge to the Relationships addon.
##
## The addon is found through the project's global class list and driven with dynamic
## calls, so Behaviors runs without it. Factions are given by ID or by name. An empty
## faction means the faction of the actor's faction member.

const _API_CLASS := "Relationships"

static var _scripts: Dictionary = {}


## True when the Relationships addon is installed.
static func is_available() -> bool:
	return _get_script(_API_CLASS) != null


## True when the addon is installed and a faction manager is active.
static func has_manager() -> bool:
	var api := _get_script(_API_CLASS)
	return api != null and api.call("get_manager") != null


## Forgets cached lookups. Call this if the addon is enabled while running.
static func reset_cache() -> void:
	_scripts.clear()


## The judge's affinity to the subject, or 0 when unavailable.
static func get_affinity(actor: Node, judge: Variant, subject: Variant) -> float:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		return 0.0
	return api.call("get_affinity", resolve_faction(actor, judge), resolve_faction(actor, subject))


## The name of the judge's affinity tier toward the subject, or an empty string.
static func get_tier_name(actor: Node, judge: Variant, subject: Variant) -> String:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		return ""
	return api.call("get_tier_name", resolve_faction(actor, judge), resolve_faction(actor, subject))


## Whether the judge's tier toward the subject is the named tier, or at least that tier.
static func is_tier(actor: Node, judge: Variant, subject: Variant, tier_name: String, at_least: bool) -> bool:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		return false
	var judge_faction: Variant = resolve_faction(actor, judge)
	var subject_faction: Variant = resolve_faction(actor, subject)
	if at_least:
		return api.call("is_at_least_tier", judge_faction, subject_faction, tier_name)
	return api.call("is_tier", judge_faction, subject_faction, tier_name)


## Turns a faction given as an ID, a name or a node into something the addon accepts. An
## empty value or a node gives the faction of the nearest faction member. Returns the
## value itself when there is no member.
static func resolve_faction(actor: Node, faction: Variant) -> Variant:
	var node: Node = null
	if faction is Node:
		node = faction
	elif faction is String and faction.is_empty():
		node = actor
	if node == null:
		return faction
	var member := _find_near(node, "FactionMember")
	return member.get("faction_id") if member else faction


## Reports that [param actor] did the deed [param tag] to [param target]. The deed
## comes from the actor's DeedReporter when its library knows the tag, and from
## [param impact] and [param aggression] otherwise. Returns whether it was reported.
static func report_deed(actor: Node, tag: String, target: Variant, magnitude: float, impact: float, aggression: float) -> bool:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		push_warning("Behaviors: the Relationships package is not available, so the deed \"%s\" was not reported." % tag)
		return false
	var manager: Object = api.call("get_manager")
	var target_node: Node = target if target is Node else null
	var reporter := _find_near(actor, "DeedReporter")
	if reporter != null:
		var library: Object = reporter.get("deed_template_library")
		if library != null and library.call("find_template", tag) != null:
			var target_arg: Variant = _find_near(target_node, "FactionMember") if target_node != null else target
			if target_arg != null:
				reporter.call("report_deed", tag, target_arg, magnitude)
				return true
	var member := _find_near(actor, "FactionMember")
	if member == null:
		push_warning("Behaviors: the deed \"%s\" needs a faction member near the actor." % tag)
		return false
	var database: Object = manager.call("get_database")
	var target_id := -1
	if target_node != null:
		var target_member := _find_near(target_node, "FactionMember")
		if target_member != null:
			target_id = target_member.get("faction_id")
	elif database != null:
		target_id = database.call("to_faction_id", target)
	if target_id < 0 or database == null or database.call("get_faction", target_id) == null:
		push_warning("Behaviors: the deed \"%s\" needs a target faction." % tag)
		return false
	var deed_script := _get_script("Deed")
	if deed_script == null:
		return false
	var power_level := 1.0
	var power_callable: Variant = member.get("get_power_level")
	if power_callable is Callable and power_callable.is_valid():
		power_level = power_callable.call()
	var deed: Object = deed_script.call("create", tag, member.get("faction_id"), target_id,
			clampf(impact * magnitude, -100.0, 100.0), aggression, power_level)
	manager.call("commit_deed", member, deed)
	return true


static func _get_script(global_name: String) -> Script:
	if _scripts.has(global_name):
		return _scripts[global_name]
	var script: Script = null
	for info in ProjectSettings.get_global_class_list():
		if info.get("class", "") == global_name:
			script = load(info["path"]) as Script
			break
	_scripts[global_name] = script
	return script


# Finds a node with the given global class on [param node], below it, or on its
# ancestors and their direct children, stopping at the owner of the scene.
static func _find_near(node: Node, global_name: String) -> Node:
	if node == null:
		return null
	if _has_global_name(node, global_name):
		return node
	for child in node.find_children("*", "", true, false):
		if _has_global_name(child, global_name):
			return child
	var ancestor := node.get_parent()
	while ancestor != null:
		if _has_global_name(ancestor, global_name):
			return ancestor
		for child in ancestor.get_children():
			if _has_global_name(child, global_name):
				return child
		if ancestor == node.owner:
			break
		ancestor = ancestor.get_parent()
	return null


static func _has_global_name(node: Node, global_name: String) -> bool:
	var script := node.get_script() as Script
	while script != null:
		if script.get_global_name() == StringName(global_name):
			return true
		script = script.get_base_script()
	return false
