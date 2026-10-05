@tool
extends RefCounted
## Readable one-paragraph summaries of quest resources for the inspector and for
## node tooltips, such as a generator entity type or a quest node.


const SKIPPED_PROPERTIES: PackedStringArray = ["resource_local_to_scene", "resource_path", "resource_name", "script", "metadata/_custom_type_script"]


## BBCode summary of `resource`.
static func describe(resource: Resource) -> String:
	if resource == null:
		return ""
	if resource is Quest:
		return _quest(resource)
	if resource is QuestNode:
		return _node(resource)
	var title := _script_name(resource)
	var lines := PackedStringArray()
	var name_line := _display_name(resource)
	lines.append("[b]%s[/b]%s" % [title, "  [i]%s[/i]" % name_line if not name_line.is_empty() else ""])
	for property in resource.get_property_list():
		if not (property.usage & PROPERTY_USAGE_EDITOR) or not (property.usage & PROPERTY_USAGE_STORAGE):
			continue
		if SKIPPED_PROPERTIES.has(property.name):
			continue
		var value: Variant = resource.get(property.name)
		if _is_default(resource, property.name, value):
			continue
		lines.append("%s: %s" % [String(property.name).capitalize(), summarize(value)])
	return "\n".join(lines)


## Short text for any value.
static func summarize(value: Variant) -> String:
	if value is Curve:
		return "curve (%d points)" % value.point_count
	if value is Resource:
		var name_text := _display_name(value)
		return name_text if not name_text.is_empty() else _script_name(value)
	if value is Array:
		if value.is_empty():
			return "none"
		var parts := PackedStringArray()
		for item in value:
			parts.append(summarize(item))
			if parts.size() >= 4:
				break
		var more := " (+%d)" % (value.size() - parts.size()) if value.size() > parts.size() else ""
		return ", ".join(parts) + more
	if value is String:
		var text: String = value.replace("\n", " ")
		return "\"%s\"" % (text.left(60) + ("..." if text.length() > 60 else ""))
	if value is float:
		return str(snappedf(value, 0.001))
	return str(value)


static func _quest(quest: Quest) -> String:
	var lines := PackedStringArray()
	lines.append("[b]%s[/b]  [i]%s[/i]" % [quest.title if not quest.title.is_empty() else "(untitled)", quest.id])
	lines.append("%d nodes, %d counters" % [quest.node_list.size(), quest.counter_list.size()])
	if not quest.requires_quests.is_empty():
		lines.append("Requires: " + ", ".join(quest.requires_quests))
	if quest.time_limit > 0.0:
		lines.append("Time limit: %d s" % int(quest.time_limit))
	return "\n".join(lines)


static func _node(node: QuestNode) -> String:
	var lines := PackedStringArray()
	lines.append("[b]%s[/b]  [i]%s[/i]" % [QuestNode.Type.keys()[node.node_type].capitalize(), node.id])
	if node.is_optional:
		lines.append("Optional")
	if node.condition_set != null:
		for condition in node.condition_set.condition_list:
			if condition != null:
				lines.append("If: " + condition.get_editor_name())
	for state in node.state_info_list.size():
		var info := node.state_info_list[state]
		if info == null:
			continue
		for action in info.action_list:
			if action != null:
				lines.append("%s: %s" % [QuestNode.State.keys()[state].capitalize(), action.get_editor_name()])
	return "\n".join(lines)


static func _display_name(resource: Variant) -> String:
	if resource is QuestSubasset:
		return resource.get_editor_name()
	for candidate in ["display_name", "name", "resource_name"]:
		if candidate in resource:
			var text: Variant = resource.get(candidate)
			if text is String and not text.is_empty():
				return text
	if resource is Resource and not resource.resource_path.is_empty() and not "::" in resource.resource_path:
		return resource.resource_path.get_file().get_basename()
	return ""


static func _script_name(resource: Object) -> String:
	var script: Script = resource.get_script()
	var global_name := script.get_global_name() if script != null else ""
	return global_name if not global_name.is_empty() else resource.get_class()


static func _is_default(resource: Resource, property_name: StringName, value: Variant) -> bool:
	var script: Script = resource.get_script()
	if script != null:
		var default: Variant = script.get_property_default_value(property_name)
		if default != null and not value is Object:
			return var_to_str(default) == var_to_str(value)
	if value == null:
		return true
	if value is String or value is Array or value is Dictionary:
		return value.is_empty()
	return false
