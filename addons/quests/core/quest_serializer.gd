class_name QuestSerializer
extends RefCounted
## Converts quests to and from dictionaries that contain only booleans,
## numbers, strings, arrays and dictionaries, so the Save addon and JSON can
## store them.
##
## There are two forms. [method state_to_dict] records just the runtime state
## of a quest that is also an authored asset. [method quest_to_dict] records
## the whole quest too, for quests that exist only at runtime, such as
## generated ones.
##
## Resources are written generically as {"type": class name, "script": path,
## "props": {exported properties}}. Textures, audio and scenes are written as
## {"__res": path}, so they must have a resource path. Other builtin types
## such as vectors are written as {"__var": text}.

const VERSION := 3

static var _scripts_by_name := {}


#region Quest state

## The runtime state of [param quest]: state, tags, counters, node states,
## condition progress and indicators. Counters, nodes and indicators are
## omitted while the quest is waiting to start, unless
## [member Quest.save_all_if_waiting_to_start] is set.
static func state_to_dict(q: Quest) -> Dictionary:
	q.update_cooldown()
	var d := {
		"version": VERSION,
		"state": int(q.get_state()),
		"tags": q.tag_dictionary.duplicate(),
		"giver": q.quest_giver_id,
		"times_accepted": q.times_accepted,
		"cooldown": q.cooldown_seconds_remaining,
		"tracking": q.show_in_track_hud,
		"autostart": _condition_set_to_dict(q.autostart_condition_set),
		"offer": _condition_set_to_dict(q.offer_condition_set),
	}
	if q.get_state() == Quest.State.WAITING_TO_START and not q.save_all_if_waiting_to_start:
		return d
	var counters := {}
	for counter in q.counter_list:
		if counter != null:
			counters[counter.name] = counter.current_value
	d["counters"] = counters
	var nodes: Array[Dictionary] = []
	for node in q.node_list:
		nodes.append({
			"id": node.id,
			"state": int(node.get_state()),
			"conditions": _condition_set_to_dict(node.condition_set),
			"tags": node.tag_dictionary.duplicate(),
		})
	d["nodes"] = nodes
	d["indicators"] = q.indicator_states.duplicate()
	d["time_remaining"] = q.time_remaining
	return d


## Restores state recorded by [method state_to_dict] into [param q]. Doesn't
## run state actions or send most messages.
static func apply_state(q: Quest, d: Dictionary) -> void:
	var saved_state := clampi(int(d.get("state", Quest.State.WAITING_TO_START)), 0, Quest.NUM_STATES - 1)
	var tags: Dictionary = d.get("tags", {})
	q.tag_dictionary.clear()
	for key: String in tags:
		q.tag_dictionary[key] = tags[key]
	q.quest_giver_id = str(d.get("giver", ""))
	q.times_accepted = int(d.get("times_accepted", 0))
	q.cooldown_seconds_remaining = float(d.get("cooldown", 0.0))
	q.show_in_track_hud = bool(d.get("tracking", true))
	# Wire references first so condition checking started below isn't undone.
	q.set_runtime_references()
	_apply_condition_set(q.autostart_condition_set, d.get("autostart", {}))
	_apply_condition_set(q.offer_condition_set, d.get("offer", {}))
	if saved_state == Quest.State.WAITING_TO_START and not d.has("counters"):
		q.set_state(saved_state as Quest.State, false)
		return
	var counters: Dictionary = d.get("counters", {})
	for counter_name: String in counters:
		var counter := q.get_counter(counter_name)
		if counter != null:
			counter.set_value(int(counters[counter_name]), QuestCounter.SetMode.DONT_INFORM_LISTENERS)
	for node_data: Dictionary in d.get("nodes", []):
		var node := q.get_node(str(node_data.get("id", "")))
		if node == null:
			continue
		_apply_condition_set(node.condition_set, node_data.get("conditions", {}))
		var node_tags: Dictionary = node_data.get("tags", {})
		node.tag_dictionary.clear()
		for key: String in node_tags:
			node.tag_dictionary[key] = node_tags[key]
		node.set_state(clampi(int(node_data.get("state", 0)), 0, QuestNode.NUM_STATES - 1) as QuestNode.State, false)
	q.indicator_states.clear()
	var indicators: Dictionary = d.get("indicators", {})
	for entity_id: String in indicators:
		q.indicator_states[entity_id] = int(indicators[entity_id])
	q.time_remaining = float(d.get("time_remaining", 0.0))
	q.set_state(saved_state as Quest.State, false)
	QuestMessages.quest_state_changed(q, q.id, q.get_state())


static func _condition_set_to_dict(condition_set: QuestConditionSet) -> Dictionary:
	if condition_set == null:
		return {}
	var already_true: Array[bool] = []
	for condition in condition_set.condition_list:
		already_true.append(condition != null and condition.already_true)
	return {"num_true": condition_set.num_true_conditions, "already_true": already_true}


static func _apply_condition_set(condition_set: QuestConditionSet, d: Dictionary) -> void:
	if condition_set == null or d.is_empty():
		return
	condition_set.num_true_conditions = clampi(int(d.get("num_true", 0)), 0, condition_set.condition_list.size())
	var already_true: Array = d.get("already_true", [])
	for i in mini(already_true.size(), condition_set.condition_list.size()):
		var condition := condition_set.condition_list[i]
		if condition != null:
			condition.already_true = bool(already_true[i])

#endregion

#region Full quest

## The whole quest: its definition and its runtime state.
static func quest_to_dict(q: Quest) -> Dictionary:
	return {"version": VERSION, "definition": encode_resource(q), "runtime": state_to_dict(q)}


## Builds a runtime instance from [method quest_to_dict]. Returns null if the
## data can't be read.
static func dict_to_quest(d: Dictionary) -> Quest:
	if not d.has("definition"):
		push_warning("Quests: Can't restore quest: the data has no definition.")
		return null
	var q := decode_resource(d.definition) as Quest
	if q == null:
		push_warning("Quests: Can't restore quest: the definition isn't a quest.")
		return null
	q.is_instance = true
	q.initialize()
	if d.has("runtime"):
		apply_state(q, d.runtime)
	return q

#endregion

#region Generic resources

## Writes a resource's exported properties as a dictionary.
static func encode_resource(resource: Resource) -> Variant:
	if resource == null:
		return null
	if not resource.resource_path.is_empty() and not resource.resource_path.contains("::") and resource.get_script() == null:
		return {"__res": resource.resource_path}
	var script := resource.get_script() as Script
	if script == null:
		push_warning("Quests: Can't serialize %s without a path." % resource.get_class())
		return null
	var props := {}
	for info in resource.get_property_list():
		var usage: int = info.usage
		if usage & PROPERTY_USAGE_STORAGE and usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			props[info.name] = encode_value(resource.get(info.name))
	return {"type": String(script.get_global_name()), "script": script.resource_path, "props": props}


static func encode_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return String(value)
		TYPE_OBJECT:
			return encode_resource(value as Resource)
		TYPE_ARRAY:
			var encoded := []
			for item in value:
				encoded.append(encode_value(item))
			return encoded
		TYPE_DICTIONARY:
			var map := {}
			for key in value:
				map[str(key)] = encode_value(value[key])
			return {"__map": map}
	return {"__var": var_to_str(value)}


static func decode_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var decoded := []
		for item in value:
			decoded.append(decode_value(item))
		return decoded
	if typeof(value) != TYPE_DICTIONARY:
		return value
	if value.has("__map"):
		var map := {}
		for key in value.__map:
			map[key] = decode_value(value.__map[key])
		return map
	if value.has("__var"):
		return str_to_var(value.__var)
	return decode_resource(value)


## Creates a resource from the dictionary written by [method encode_resource].
static func decode_resource(d: Variant) -> Resource:
	if typeof(d) != TYPE_DICTIONARY:
		return null
	if d.has("__res"):
		return load(d.__res) if ResourceLoader.exists(d.__res) else null
	var script := _find_script(str(d.get("type", "")), str(d.get("script", "")))
	if script == null:
		push_warning("Quests: Can't find the class '%s' to restore." % d.get("type", ""))
		return null
	var resource: Resource = script.new()
	var types := {}
	for info in resource.get_property_list():
		types[info.name] = info.type
	var props: Dictionary = d.get("props", {})
	for key: String in props:
		if not types.has(key):
			continue
		_set_property(resource, key, types[key], decode_value(props[key]))
	return resource


static func _set_property(resource: Resource, key: String, type: int, value: Variant) -> void:
	match type:
		TYPE_INT:
			value = int(value) if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT else value
		TYPE_FLOAT:
			value = float(value) if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT else value
		TYPE_ARRAY:
			var target: Array = resource.get(key)
			target.clear()
			target.assign(value)
			return
		TYPE_DICTIONARY:
			var target: Dictionary = resource.get(key)
			target.clear()
			target.merge(value)
			return
		TYPE_PACKED_STRING_ARRAY:
			value = PackedStringArray(value)
	resource.set(key, value)


static func _find_script(type_name: String, path: String) -> Script:
	if not type_name.is_empty():
		if not _scripts_by_name.has(type_name):
			# Classes may have been added since the last lookup.
			for entry in ProjectSettings.get_global_class_list():
				_scripts_by_name[entry["class"]] = entry["path"]
		if _scripts_by_name.has(type_name):
			return load(_scripts_by_name[type_name]) as Script
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path) as Script
	return null

#endregion
