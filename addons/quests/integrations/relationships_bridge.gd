class_name QuestsRelationships
extends RefCounted
## Optional bridge to the Relationships addon.
##
## The addon is detected at runtime through the project's global class list and
## driven with dynamic calls, so Quests parses and runs without it. Factions can
## be given by ID or by name.
## [codeblock]
## if QuestsRelationships.is_available():
##     print(QuestsRelationships.get_tier_name("Villagers", "Player"))
## [/codeblock]

const _API_CLASS := "Relationships"

static var _scripts: Dictionary = {}


## Whether the Relationships addon is installed.
static func is_available() -> bool:
	return _get_script(_API_CLASS) != null


## Whether the addon is installed and a faction manager is active.
static func has_manager() -> bool:
	return get_manager() != null


## The active faction manager, or null.
static func get_manager() -> Object:
	var api := _get_script(_API_CLASS)
	if api == null:
		return null
	return api.call("get_manager")


## Forgets cached lookups. Call this if the addon is enabled while running.
static func reset_cache() -> void:
	_scripts.clear()


## The judge's affinity to the subject, or 0 if unavailable.
static func get_affinity(judge: Variant, subject: Variant) -> float:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		return 0.0
	return api.call("get_affinity", judge, subject)


## The name of the judge's affinity tier toward the subject, or an empty string.
static func get_tier_name(judge: Variant, subject: Variant) -> String:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		return ""
	return api.call("get_tier_name", judge, subject)


## Whether the judge's affinity reaches the named tier or a higher one.
static func is_at_least_tier(judge: Variant, subject: Variant, tier_name: String) -> bool:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		return false
	return api.call("is_at_least_tier", judge, subject, tier_name)


## Compares the judge's affinity with [param value]. [param comparison] is one of
## [code]<[/code], [code]<=[/code], [code]==[/code], [code]!=[/code], [code]>=[/code], [code]>[/code].
static func check(judge: Variant, subject: Variant, comparison: String, value: float) -> bool:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		return false
	return api.call("check", judge, subject, comparison, value)


## Whether the faction (ID or name) exists.
static func has_faction(faction: Variant) -> bool:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		return false
	return api.call("get_faction", faction, true) != null


## Changes the judge's personal affinity to the subject by [param change].
## Returns false (with a warning) if the addon isn't available.
static func modify_affinity(judge: Variant, subject: Variant, change: float) -> bool:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		push_warning("Quests: Relationships isn't available; can't modify affinity.")
		return false
	api.call("modify_personal_affinity", judge, subject, change)
	return true


## Sets the judge's personal affinity to the subject.
static func set_affinity(judge: Variant, subject: Variant, affinity: float) -> bool:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		push_warning("Quests: Relationships isn't available; can't set affinity.")
		return false
	api.call("set_personal_affinity", judge, subject, affinity)
	return true


## Reports that [param actor] did the deed [param tag] to [param target].
## [param actor] is a node of the character that did it, or a faction ID or name.
## [param target] is a faction ID or name, or a node of the character it was done to.
## If the actor has a DeedReporter whose library knows [param tag], its template is
## used (scaled by [param magnitude]). Otherwise a deed is built from
## [param impact] and [param aggression], with the impact scaled by [param magnitude].
## Returns whether the deed was reported.
static func report_deed(actor: Variant, tag: String, target: Variant, magnitude := 1.0,
		impact := 0.0, aggression := 0.0) -> bool:
	var api := _get_script(_API_CLASS)
	if api == null or not has_manager():
		push_warning("Quests: Relationships isn't available; can't report deed '%s'." % tag)
		return false
	var manager: Object = api.call("get_manager")
	var actor_node: Node = actor if actor is Node else null
	var target_node: Node = target if target is Node else null
	if actor_node != null:
		var reporter := _find_near(actor_node, "DeedReporter")
		if reporter != null:
			var library: Object = reporter.get("deed_template_library")
			if library != null and library.call("find_template", tag) != null:
				var target_arg: Variant = _find_near(target_node, "FactionMember") if target_node != null else target
				if target_arg != null:
					reporter.call("report_deed", tag, target_arg, magnitude)
					return true
	var member: Object = _find_near(actor_node, "FactionMember") if actor_node != null else null
	if member == null:
		push_warning("Quests: report_deed('%s') can't find a faction member for the actor." % tag)
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
		push_warning("Quests: report_deed('%s') can't find the target faction." % tag)
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


# Finds a node whose script has the given global class name on [param node], below
# it, or on its ancestors and their direct children. The ancestor search stops at
# the node's owner (the root of its scene) when it has one.
static func _find_near(node: Node, global_name: String) -> Node:
	if node == null:
		return null
	var found := _find_below(node, global_name)
	if found != null:
		return found
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


static func _find_below(node: Node, global_name: String) -> Node:
	if _has_global_name(node, global_name):
		return node
	for child in node.find_children("*", "", true, false):
		if _has_global_name(child, global_name):
			return child
	return null


static func _has_global_name(node: Node, global_name: String) -> bool:
	var script := node.get_script() as Script
	while script != null:
		if script.get_global_name() == StringName(global_name):
			return true
		script = script.get_base_script()
	return false
