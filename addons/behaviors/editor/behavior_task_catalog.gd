@tool
class_name BehaviorTaskCatalog
extends RefCounted
## Finds every task class of the project for the palette and the menus, and reads the
## documentation comment of a task script.

const PACKAGE_ROOT := "res://addons/behaviors/"

static var _classes: Dictionary = {}
static var _entries: Array[Dictionary] = []
static var _docs: Dictionary = {}
static var _icon_paths: Dictionary = {}
static var _loaded := false


## Forgets what was found, so the next call looks at the project again.
static func refresh() -> void:
	_loaded = false
	_docs.clear()
	_icon_paths.clear()


## Every task that can be added to a tree. Each entry has [code]class_name[/code],
## [code]path[/code], [code]script[/code], [code]name[/code], [code]kind[/code]
## ([code]composite[/code], [code]decorator[/code], [code]action[/code],
## [code]condition[/code] or [code]subtree[/code]) and [code]category[/code], a path
## of names such as [code]["Actions", "Movement"][/code].
static func get_entries() -> Array[Dictionary]:
	_load()
	return _entries


## True when the global class [param name] is [param base] or extends it.
static func class_inherits(name: String, base: String) -> bool:
	_load()
	var current := name
	var guard := 0
	while not current.is_empty() and guard < 64:
		if current == base:
			return true
		current = _classes.get(current, {}).get("base", "")
		guard += 1
	return false


## True when [param script] is [param base_class] or extends it.
static func script_is_a(script: Script, base_class: String) -> bool:
	var current := script
	while current:
		if String(current.get_global_name()) == base_class:
			return true
		current = current.get_base_script()
	return false


## The names of the global classes between [param script] and [BehaviorTask].
static func get_class_chain(script: Script) -> PackedStringArray:
	var chain := PackedStringArray()
	var current := script
	while current:
		var global_name := String(current.get_global_name())
		if not global_name.is_empty():
			chain.append(global_name)
		current = current.get_base_script()
	return chain


## The kind of a task script. See [method get_entries].
static func get_kind(script: Script) -> String:
	if script_is_a(script, "BehaviorSubtree"):
		return "subtree"
	if script_is_a(script, "BehaviorComposite"):
		return "composite"
	if script_is_a(script, "BehaviorDecorator"):
		return "decorator"
	if script_is_a(script, "BehaviorCondition"):
		return "condition"
	if script_is_a(script, "BehaviorParent"):
		return "composite"
	return "action"


## The icon of a task script, taken from its [code]@icon[/code] or the nearest base
## class that has one. Null when no icon file exists.
static func get_icon(script: Script) -> Texture2D:
	_load()
	var current := script
	while current:
		var global_name := String(current.get_global_name())
		if _icon_paths.has(global_name):
			return _icon_paths[global_name]
		var path: String = _classes.get(global_name, {}).get("icon", "")
		if not path.is_empty() and ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			_icon_paths[global_name] = texture
			return texture
		current = current.get_base_script()
	return null


## True when the task, or one of its bases other than the task root, holds tasks in
## properties that the editor edits in place.
static func holds_inline_tasks(task: BehaviorTask) -> bool:
	var current: Script = task.get_script()
	while current and not current.resource_path.begins_with(PACKAGE_ROOT + "core/"):
		for method in current.get_script_method_list():
			if method.name == "_get_inline_tasks":
				return true
		current = current.get_base_script()
	return false


## The leading documentation comment of a task script as plain text, without markup.
static func get_doc(script: Script) -> String:
	if script == null:
		return ""
	var key := script.resource_path
	if _docs.has(key):
		return _docs[key]
	var text := _parse_doc(script.source_code)
	_docs[key] = text
	return text


static func _parse_doc(source: String) -> String:
	var lines: Array[String] = []
	var in_doc := false
	var passed_header := false
	for line in source.split("\n"):
		var stripped := line.strip_edges()
		if not passed_header:
			if stripped.begins_with("extends"):
				passed_header = true
			continue
		if stripped.begins_with("##"):
			in_doc = true
			lines.append(stripped.trim_prefix("##").trim_prefix(" "))
		elif in_doc or not stripped.is_empty():
			break
	return _plain("\n".join(lines)).strip_edges()


static func _plain(text: String) -> String:
	var result := text.replace("[br]", "\n")
	var markup := RegEx.new()
	markup.compile("\\[/?(b|i|u|s|code|codeblock|center)\\]")
	result = markup.sub(result, "", true)
	var reference := RegEx.new()
	reference.compile("\\[(?:method|member|constant|signal|param|enum|class|annotation)\\s+([^\\]]+)\\]")
	result = reference.sub(result, "$1", true)
	var type_name := RegEx.new()
	type_name.compile("\\[([A-Za-z_][A-Za-z_0-9.]*)\\]")
	result = type_name.sub(result, "$1", true)
	var blank := RegEx.new()
	blank.compile("\\n{3,}")
	return blank.sub(result, "\n\n", true)


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_classes.clear()
	_entries.clear()
	for info in ProjectSettings.get_global_class_list():
		_classes[String(info["class"])] = info
	for global_name: String in _classes:
		if global_name == "BehaviorTask" or not class_inherits(global_name, "BehaviorTask"):
			continue
		var info: Dictionary = _classes[global_name]
		var script := load(String(info["path"])) as Script
		if script == null or script.is_abstract() or not script.can_instantiate():
			continue
		var kind := get_kind(script)
		_entries.append({
			"class_name": global_name,
			"path": String(info["path"]),
			"script": script,
			"name": BehaviorTask.get_type_name(script),
			"kind": kind,
			"category": _category_of(String(info["path"]), kind),
		})
	_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := "/".join(a["category"]) + "/" + String(a["name"])
		var right := "/".join(b["category"]) + "/" + String(b["name"])
		return left.naturalnocasecmp_to(right) < 0)


static func _category_of(path: String, kind: String) -> PackedStringArray:
	if not path.begins_with(PACKAGE_ROOT):
		return PackedStringArray(["Custom"])
	var parts := path.trim_prefix(PACKAGE_ROOT).split("/")
	if parts.size() >= 3 and (parts[0] == "actions" or parts[0] == "conditions"):
		return PackedStringArray([String(parts[0]).capitalize(), String(parts[1]).capitalize()])
	if kind == "composite":
		return PackedStringArray(["Composites"])
	if kind == "decorator" or kind == "subtree":
		return PackedStringArray(["Decorators"])
	return PackedStringArray([String(parts[0]).capitalize()])
