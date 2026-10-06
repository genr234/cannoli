class_name QuestTextExtractor
extends RefCounted
## Finds the player-facing strings in quest, database and generator resources:
## titles, groups, content text, counter display names and verb texts. Words in
## {Word} tags are included too, because the tags are looked up with tr() at
## runtime. Used by the translation parser plugin, and usable from scripts and tools.

## Translatable string properties by class. A subclass also uses the entries of
## its parents.
const TRANSLATABLE := {
	"Quest": ["title", "group"],
	"QuestCounter": ["display_name"],
	"QuestHeadingContent": ["text"],
	"QuestBodyContent": ["text"],
	"QuestIconContent": ["caption"],
	"QuestAudioContent": ["text"],
	"QuestEntityType": ["display_name", "plural_display_name"],
	"QuestDomainType": ["display_name"],
	"QuestVerb": ["display_name"],
	"QuestMotive": ["text"],
	"QuestVerbStateText": ["dialogue_text", "journal_text", "hud_text", "alert_text"],
	"QuestVerbText": ["success_text"],
}

## Tags that the runtime replaces itself and that are not translation keys.
const BUILT_IN_TAGS: PackedStringArray = [
	"QUESTID", "QUEST", "QUESTGIVER", "QUESTGIVERID", "QUESTER", "QUESTERID", "GREETER", "GREETERID",
	"DOMAIN", "ACTION", "TARGETDESCRIPTOR", "TARGET", "TARGETS", "TARGETENTITY", "COUNTERGOAL", "REWARD",
]

const MAX_DEPTH := 32


## Reads a resource file and returns POT entries: [msgid, msgctxt, msgid_plural, comment].
static func parse_file(path: String) -> Array[PackedStringArray]:
	var result: Array[PackedStringArray] = []
	var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if resource == null:
		return result
	for entry in extract(resource):
		result.append(PackedStringArray([entry.text, "", "", entry.comment]))
	return result


## Returns {text, comment} for every translatable string in `resource` and the
## resources embedded in it. Strings appear once, in the order found.
static func extract(resource: Resource) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var seen_text := {}
	_walk(resource, "", found, seen_text, {}, 0, true)
	return found


static func _walk(value: Variant, label: String, found: Array[Dictionary], seen_text: Dictionary, visited: Dictionary, depth: int, is_root: bool) -> void:
	if depth > MAX_DEPTH:
		return
	if value is Resource:
		var resource: Resource = value
		if visited.has(resource):
			return
		visited[resource] = true
		var is_external := not resource.resource_path.is_empty() and not "::" in resource.resource_path
		if is_external and not is_root:
			return
		var own_label := _label_for(resource, label)
		for property_name in _translatable_properties(resource):
			var text: Variant = resource.get(property_name)
			if text is String and not text.strip_edges().is_empty():
				if resource is QuestHeadingContent and resource.use_quest_title:
					continue
				_add(found, seen_text, text, "%s: %s" % [own_label, property_name])
		for property in resource.get_property_list():
			if not (property.usage & PROPERTY_USAGE_STORAGE):
				continue
			if property.type == TYPE_OBJECT or property.type == TYPE_ARRAY or property.type == TYPE_DICTIONARY:
				_walk(resource.get(property.name), own_label, found, seen_text, visited, depth + 1, false)
	elif value is Array:
		for item in value:
			_walk(item, label, found, seen_text, visited, depth + 1, false)
	elif value is Dictionary:
		for item in value.values():
			_walk(item, label, found, seen_text, visited, depth + 1, false)


static func _add(found: Array[Dictionary], seen_text: Dictionary, text: String, comment: String) -> void:
	if not seen_text.has(text):
		seen_text[text] = true
		found.append({"text": text, "comment": comment})
	for tag in extract_tags(text):
		if not seen_text.has(tag):
			seen_text[tag] = true
			found.append({"text": tag, "comment": "Tag used in: " + comment})


## The words in {Word} tags that are looked up with tr().
static func extract_tags(text: String) -> PackedStringArray:
	var tags := PackedStringArray()
	var regex := RegEx.create_from_string("\\{([^{}#<>:\\s][^{}#<>:]*)\\}")
	for match in regex.search_all(text):
		var word := match.get_string(1).strip_edges()
		if not word.is_empty() and not BUILT_IN_TAGS.has(word) and not word.is_valid_int() and not tags.has(word):
			tags.append(word)
	return tags


static func _translatable_properties(resource: Resource) -> PackedStringArray:
	var names := PackedStringArray()
	var script: Script = resource.get_script()
	while script != null:
		var global_name := script.get_global_name()
		if TRANSLATABLE.has(global_name):
			for property_name: String in TRANSLATABLE[global_name]:
				if not names.has(property_name):
					names.append(property_name)
		script = script.get_base_script()
	return names


static func _label_for(resource: Resource, parent_label: String) -> String:
	if resource is Quest:
		return "Quest %s" % resource.id
	if resource is QuestNode:
		return "%s, node %s" % [parent_label, resource.id]
	if resource is QuestCounter:
		return "%s, counter %s" % [parent_label, resource.name]
	return parent_label if not parent_label.is_empty() else resource.get_class()
