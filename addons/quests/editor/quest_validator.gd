class_name QuestValidator
extends RefCounted
## Checks a quest (or every quest in a database or list) for authoring mistakes.
## Does not use any editor-only API, so it can be called from tools and from
## game code. Every check has a severity so the editor can sort problems.

enum Severity { WARNING, ERROR }


## Returns one human-readable string per problem, errors first.
static func validate(quest: Quest, known_quest_ids: PackedStringArray = PackedStringArray()) -> Array[String]:
	var result: Array[String] = []
	for issue in validate_issues(quest, known_quest_ids):
		result.append(issue.message)
	return result


## Returns problems as dictionaries: {message, severity, node_id, kind}. `node_id`
## is empty when the problem concerns the quest as a whole.
static func validate_issues(quest: Quest, known_quest_ids: PackedStringArray = PackedStringArray()) -> Array[Dictionary]:
	var issues: Array[Dictionary] = []
	if quest == null:
		issues.append(_issue("Quest is null.", Severity.ERROR, "", "null"))
		return issues
	_check_quest_info(quest, known_quest_ids, issues)
	_check_counters(quest, issues)
	_check_nodes(quest, issues)
	_check_references(quest, issues)
	issues.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.severity > b.severity)
	return issues


## Validates every quest in `quests` and checks ids across the set.
static func validate_quests(quests: Array) -> Array[String]:
	var result: Array[String] = []
	var ids := PackedStringArray()
	for quest: Quest in quests:
		if quest != null and not quest.id.is_empty():
			ids.append(quest.id)
	var seen: Dictionary[String, int] = {}
	for quest: Quest in quests:
		if quest == null:
			result.append("The list contains an empty quest slot.")
			continue
		if not quest.id.is_empty():
			seen[quest.id] = seen.get(quest.id, 0) + 1
			if seen[quest.id] == 2:
				result.append("Duplicate quest id '%s'." % quest.id)
		for message in validate(quest, ids):
			result.append("%s: %s" % [quest.id if not quest.id.is_empty() else quest.title, message])
	return result


static func validate_database(database: QuestDatabase) -> Array[String]:
	if database == null:
		return []
	return validate_quests(database.quest_assets)


## For `_get_configuration_warnings()` implementations on nodes that hold quests.
static func get_list_warnings(quests: Array) -> PackedStringArray:
	return PackedStringArray(validate_quests(quests))


## Returns every counter name used by `quest`'s own nodes, conditions and actions
## that is not defined in the quest.
static func find_missing_counters(quest: Quest) -> PackedStringArray:
	var missing := PackedStringArray()
	if quest == null:
		return missing
	var names := _counter_names(quest)
	for entry in collect_subassets(quest):
		for counter_name in _referenced_counters(entry.asset, quest):
			if not counter_name.is_empty() and not names.has(counter_name) and not missing.has(counter_name):
				missing.append(counter_name)
	return missing


## Every subasset (condition, action, content) under the quest as
## {asset: Resource, node_id: String, where: String}.
static func collect_subassets(quest: Quest) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if quest == null:
		return entries
	_collect_condition_set(quest.autostart_condition_set, "", "Autostart", entries)
	_collect_condition_set(quest.offer_condition_set, "", "Offer", entries)
	_collect_contents(quest.offer_conditions_unmet_content_list, "", "Offer unmet", entries)
	_collect_contents(quest.offer_content_list, "", "Offer", entries)
	for state in quest.state_info_list.size():
		_collect_state_info(quest.state_info_list[state], "", "State %s" % _quest_state_name(state), entries)
	for node in quest.node_list:
		if node == null:
			continue
		_collect_condition_set(node.condition_set, node.id, "Conditions", entries)
		for state in node.state_info_list.size():
			_collect_state_info(node.state_info_list[state], node.id, "State %s" % _node_state_name(state), entries)
	return entries


static func _check_quest_info(quest: Quest, known_quest_ids: PackedStringArray, issues: Array[Dictionary]) -> void:
	if quest.id.is_empty():
		issues.append(_issue("Quest has no id.", Severity.ERROR, "", "quest_id"))
	if quest.title.strip_edges().is_empty():
		issues.append(_issue("Quest '%s' has an empty title." % quest.id, Severity.WARNING, "", "title"))
	if quest.max_times < 1 and not quest.infinitely_repeatable:
		issues.append(_issue("Max times is below 1, so the quest can never be offered.", Severity.WARNING, "", "max_times"))
	if quest.time_limit < 0.0:
		issues.append(_issue("Time limit is negative.", Severity.ERROR, "", "time_limit"))
	if not known_quest_ids.is_empty():
		for required in quest.requires_quests:
			if not known_quest_ids.has(required):
				issues.append(_issue("Requires quest '%s', which does not exist." % required, Severity.ERROR, "", "requires"))
	if quest.requires_quests.has(quest.id) and not quest.id.is_empty():
		issues.append(_issue("Quest requires itself.", Severity.ERROR, "", "requires"))


static func _check_counters(quest: Quest, issues: Array[Dictionary]) -> void:
	var seen := {}
	for counter in quest.counter_list:
		if counter == null:
			issues.append(_issue("The counter list contains an empty slot.", Severity.ERROR, "", "counter"))
			continue
		if counter.name.is_empty():
			issues.append(_issue("A counter has no name.", Severity.ERROR, "", "counter"))
		elif seen.has(counter.name):
			issues.append(_issue("Duplicate counter name '%s'." % counter.name, Severity.ERROR, "", "counter"))
		seen[counter.name] = true
		if counter.min_value > counter.max_value:
			issues.append(_issue("Counter '%s' has a minimum above its maximum." % counter.name, Severity.ERROR, "", "counter"))


static func _check_nodes(quest: Quest, issues: Array[Dictionary]) -> void:
	if quest.node_list.is_empty():
		issues.append(_issue("Quest has no nodes. Add a Start node.", Severity.ERROR, "", "no_start"))
		return
	var by_id := {}
	var has_success := false
	for index in quest.node_list.size():
		var node := quest.node_list[index]
		if node == null:
			issues.append(_issue("Node slot %d is empty." % index, Severity.ERROR, "", "null_node"))
			continue
		if node.id.is_empty():
			issues.append(_issue("Node %d (%s) has no id." % [index, _label(node)], Severity.ERROR, "", "node_id"))
		elif by_id.has(node.id):
			issues.append(_issue("Duplicate node id '%s'." % node.id, Severity.ERROR, node.id, "duplicate_id"))
		else:
			by_id[node.id] = node
		if node.node_type == QuestNode.Type.SUCCESS:
			has_success = true
		if index == 0 and node.node_type != QuestNode.Type.START:
			issues.append(_issue("The first node must be the Start node.", Severity.ERROR, node.id, "no_start"))
		if index > 0 and node.node_type == QuestNode.Type.START:
			issues.append(_issue("Node '%s' is a second Start node." % node.id, Severity.WARNING, node.id, "extra_start"))
	if not has_success:
		issues.append(_issue("Quest has no Success node, so it can never be completed.", Severity.ERROR, "", "no_success"))
	for node in quest.node_list:
		if node == null:
			continue
		for child_id in node.children:
			if child_id == node.id:
				issues.append(_issue("Node '%s' lists itself as a child." % node.id, Severity.ERROR, node.id, "self_child"))
			elif not by_id.has(child_id):
				issues.append(_issue("Node '%s' has child '%s', which does not exist." % [node.id, child_id], Severity.ERROR, node.id, "missing_child"))
		var terminal := node.node_type == QuestNode.Type.SUCCESS or node.node_type == QuestNode.Type.FAILURE
		if not terminal and node.children.is_empty() and not node.id.is_empty():
			issues.append(_issue("Node '%s' is a dead end: it has no children." % node.id, Severity.WARNING, node.id, "dead_end"))
		if node.node_type == QuestNode.Type.CONDITION and (node.condition_set == null or node.condition_set.condition_list.is_empty()):
			issues.append(_issue("Condition node '%s' has no conditions, so it is true as soon as it becomes active." % node.id, Severity.WARNING, node.id, "empty_condition"))
		if node.join_mode == QuestNode.JoinMode.MIN and node.join_min_count < 1:
			issues.append(_issue("Node '%s' joins with a minimum below 1." % node.id, Severity.ERROR, node.id, "join"))
	for node in get_unreachable_nodes(quest):
		issues.append(_issue("Node '%s' cannot be reached from the Start node." % node.id, Severity.WARNING, node.id, "unreachable"))


static func _check_references(quest: Quest, issues: Array[Dictionary]) -> void:
	var counters := _counter_names(quest)
	var node_ids := {}
	for node in quest.node_list:
		if node != null:
			node_ids[node.id] = true
	var reported := {}
	for entry in collect_subassets(quest):
		var asset: Resource = entry.asset
		var owner_text: String = entry.node_id if not entry.node_id.is_empty() else "quest"
		for counter_name in _referenced_counters(asset, quest):
			if counter_name.is_empty():
				continue
			if not counters.has(counter_name):
				_report_once(reported, issues, "Node '%s': %s refers to counter '%s', which the quest does not define." % [owner_text, _asset_name(asset), counter_name], Severity.ERROR, entry.node_id, "missing_counter")
		if _targets_this_quest(asset, quest):
			var target_node: String = asset.get(_node_property(asset))
			if not target_node.is_empty() and not node_ids.has(target_node):
				_report_once(reported, issues, "Node '%s': %s refers to node '%s', which does not exist." % [owner_text, _asset_name(asset), target_node], Severity.ERROR, entry.node_id, "missing_node")
	for counter in quest.counter_list:
		if counter != null and counter.objective_goal != null and counter.objective_goal.value_type != QuestNumber.ValueType.LITERAL:
			var goal_counter := counter.objective_goal.counter_name
			if not goal_counter.is_empty() and not counters.has(goal_counter):
				_report_once(reported, issues, "Counter '%s' goal refers to counter '%s', which does not exist." % [counter.name, goal_counter], Severity.ERROR, "", "missing_counter")


static func _report_once(reported: Dictionary, issues: Array[Dictionary], message: String, severity: Severity, node_id: String, kind: String) -> void:
	if reported.has(message):
		return
	reported[message] = true
	issues.append(_issue(message, severity, node_id, kind))


## Nodes that no path from the Start node leads to.
static func get_unreachable_nodes(quest: Quest) -> Array[QuestNode]:
	var result: Array[QuestNode] = []
	if quest == null or quest.node_list.is_empty() or quest.node_list[0] == null:
		return result
	var by_id := {}
	for node in quest.node_list:
		if node != null and not node.id.is_empty() and not by_id.has(node.id):
			by_id[node.id] = node
	var visited := {}
	var queue: Array[QuestNode] = [quest.node_list[0]]
	visited[quest.node_list[0]] = true
	while not queue.is_empty():
		var node: QuestNode = queue.pop_back()
		for child_id in node.children:
			var child: QuestNode = by_id.get(child_id)
			if child != null and not visited.has(child):
				visited[child] = true
				queue.append(child)
	for node in quest.node_list:
		if node != null and not visited.has(node):
			result.append(node)
	return result


static func _counter_names(quest: Quest) -> Dictionary:
	var names := {}
	for counter in quest.counter_list:
		if counter != null:
			names[counter.name] = true
	return names


static func _referenced_counters(asset: Resource, quest: Quest = null) -> PackedStringArray:
	var names := PackedStringArray()
	if asset == null:
		return names
	if "counter_name" in asset and asset.get("counter_name") is String:
		if not refers_to_other_quest(asset, quest):
			names.append(asset.get("counter_name"))
	for property in asset.get_property_list():
		if not (property.usage & PROPERTY_USAGE_STORAGE) or property.type != TYPE_OBJECT:
			continue
		var value: Variant = asset.get(property.name)
		if value is QuestNumber and value.value_type != QuestNumber.ValueType.LITERAL:
			names.append(value.counter_name)
	return names


static func _quest_property(asset: Resource) -> String:
	for candidate in ["required_quest_id", "quest_id"]:
		if candidate in asset and asset.get(candidate) is String:
			return candidate
	return ""


static func _node_property(asset: Resource) -> String:
	for candidate in ["required_node_id", "node_id"]:
		if candidate in asset and asset.get(candidate) is String:
			return candidate
	return ""


static func refers_to_other_quest(asset: Resource, quest: Quest = null) -> bool:
	var property := _quest_property(asset)
	if property.is_empty():
		return false
	var quest_id: String = asset.get(property)
	return not quest_id.is_empty() and (quest == null or quest_id != quest.id)


static func _targets_this_quest(asset: Resource, quest: Quest) -> bool:
	return not _node_property(asset).is_empty() and not refers_to_other_quest(asset, quest)


static func _collect_condition_set(condition_set: QuestConditionSet, node_id: String, where: String, entries: Array[Dictionary]) -> void:
	if condition_set == null:
		return
	for condition in condition_set.condition_list:
		if condition != null:
			entries.append({"asset": condition, "node_id": node_id, "where": where})


static func _collect_state_info(info: QuestStateInfo, node_id: String, where: String, entries: Array[Dictionary]) -> void:
	if info == null:
		return
	for action in info.action_list:
		if action != null:
			entries.append({"asset": action, "node_id": node_id, "where": where})
	_collect_contents(info.dialogue_content, node_id, where, entries)
	_collect_contents(info.journal_content, node_id, where, entries)
	_collect_contents(info.hud_content, node_id, where, entries)


static func _collect_contents(contents: Array, node_id: String, where: String, entries: Array[Dictionary]) -> void:
	for content in contents:
		if content != null:
			entries.append({"asset": content, "node_id": node_id, "where": where})


static func _asset_name(asset: Resource) -> String:
	if asset is QuestSubasset:
		var text: String = asset.get_editor_name()
		if not text.is_empty():
			return text
	var script: Script = asset.get_script()
	return script.get_global_name() if script != null and not script.get_global_name().is_empty() else asset.get_class()


static func _label(node: QuestNode) -> String:
	return node.internal_name if not node.internal_name.is_empty() else QuestNode.Type.keys()[node.node_type].capitalize()


static func _quest_state_name(state: int) -> String:
	return Quest.State.keys()[state].capitalize() if state >= 0 and state < Quest.State.size() else str(state)


static func _node_state_name(state: int) -> String:
	return QuestNode.State.keys()[state].capitalize() if state >= 0 and state < QuestNode.State.size() else str(state)


static func _issue(message: String, severity: Severity, node_id: String, kind: String) -> Dictionary:
	return {"message": message, "severity": severity, "node_id": node_id, "kind": kind}
