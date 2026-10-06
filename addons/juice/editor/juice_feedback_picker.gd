@tool
extends PopupPanel
## A searchable popup listing every feedback class, grouped by the folder it lives in.

signal picked(script: Script)

const FALLBACK_ICON := "res://addons/juice/icons/feedback.svg"

static var _cache: Array[Dictionary] = []

var _search := LineEdit.new()
var _tree := Tree.new()


func _init() -> void:
	var box := VBoxContainer.new()
	add_child(box)
	_search.placeholder_text = "Search feedbacks..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(_fill)
	_search.text_submitted.connect(func(_text: String) -> void: _pick_first())
	box.add_child(_search)
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_SINGLE
	_tree.custom_minimum_size = Vector2(300, 380)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_selected)
	_tree.item_activated.connect(_on_selected)
	box.add_child(_tree)


## Opens the popup under [param anchor].
func open_under(anchor: Control) -> void:
	_search.text = ""
	_fill("")
	var rect := Rect2i(Vector2i(anchor.get_screen_position()) + Vector2i(0, int(anchor.size.y)), Vector2i(320, 440))
	popup(rect)
	_search.grab_focus()


## Finds every concrete feedback class of the project. Each entry has [code]script[/code],
## [code]class[/code], [code]label[/code], [code]category[/code], [code]color[/code] and [code]icon[/code].
static func list_feedback_classes(force: bool = false) -> Array[Dictionary]:
	if not _cache.is_empty() and not force:
		return _cache
	var bases: Dictionary[String, String] = {}
	var entries: Dictionary[String, Dictionary] = {}
	for entry in ProjectSettings.get_global_class_list():
		bases[entry["class"]] = entry["base"]
		entries[entry["class"]] = entry
	var found: Array[Dictionary] = []
	for class_name_text in entries:
		if not _inherits_feedback(class_name_text, bases):
			continue
		var entry := entries[class_name_text]
		var script := load(entry["path"]) as Script
		if script == null or script.is_abstract() or not script.can_instantiate():
			continue
		var sample := script.new() as JuiceFeedback
		if sample == null:
			continue
		var folder: String = String(entry["path"]).get_base_dir().get_file()
		found.append({
			"script": script,
			"class": class_name_text,
			"label": sample.get_display_label(),
			"category": folder.to_upper() if folder.length() <= 2 else folder.capitalize(),
			"color": sample.get_color(),
			"icon": String(entry.get("icon", "")),
		})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.category != b.category:
			return a.category < b.category
		return a.label.naturalnocasecmp_to(b.label) < 0)
	_cache = found
	return found


static func _inherits_feedback(start: String, bases: Dictionary[String, String]) -> bool:
	var current := start
	var guard := 0
	while bases.has(current) and guard < 64:
		current = bases[current]
		if current == "JuiceFeedback":
			return true
		guard += 1
	return false


func _fill(query: String) -> void:
	_tree.clear()
	var root := _tree.create_item()
	var needle := query.strip_edges().to_lower()
	var groups: Dictionary[String, TreeItem] = {}
	for entry in list_feedback_classes():
		var haystack := ("%s %s %s" % [entry.label, entry["class"], entry.category]).to_lower()
		if not needle.is_empty() and not haystack.contains(needle):
			continue
		var category: String = entry.category
		if not groups.has(category):
			var group := _tree.create_item(root)
			group.set_text(0, category)
			group.set_custom_color(0, Color(0.7, 0.7, 0.75))
			group.set_metadata(0, null)
			groups[category] = group
		var item := _tree.create_item(groups[category])
		item.set_text(0, entry.label)
		item.set_tooltip_text(0, entry["class"])
		item.set_metadata(0, entry.script)
		var icon_path: String = entry.icon if not String(entry.icon).is_empty() else FALLBACK_ICON
		if ResourceLoader.exists(icon_path):
			item.set_icon(0, load(icon_path) as Texture2D)
		item.set_icon_modulate(0, Color.WHITE)
	for group in groups.values():
		group.collapsed = false


func _pick_first() -> void:
	var group := _tree.get_root().get_first_child() if _tree.get_root() != null else null
	if group != null and group.get_first_child() != null:
		_emit(group.get_first_child())


func _on_selected() -> void:
	var item := _tree.get_selected()
	if item == null:
		return
	if item.get_metadata(0) == null:
		item.collapsed = not item.collapsed
		return
	_emit(item)


func _emit(item: TreeItem) -> void:
	var script := item.get_metadata(0) as Script
	if script == null:
		return
	hide()
	picked.emit(script)
