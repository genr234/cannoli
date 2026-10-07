@tool
extends VBoxContainer
## The "Tasks" side panel: a searchable tree of every task, grouped by category. Double
## click a task to add it to the canvas, or drag it there.

## A task was double-clicked. [param entry] comes from [method BehaviorTaskCatalog.get_entries].
signal task_activated(entry: Dictionary)

const DRAG_TYPE := "behavior_task"

var _search := LineEdit.new()
var _tree := Tree.new()


func _init() -> void:
	name = "Tasks"
	custom_minimum_size.x = 210.0
	var title := Label.new()
	title.text = "Tasks"
	add_child(title)
	_search.placeholder_text = "Search"
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: rebuild())
	add_child(_search)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.hide_root = true
	_tree.select_mode = Tree.SELECT_SINGLE
	_tree.item_activated.connect(_on_item_activated)
	_tree.set_drag_forwarding(_get_drag_data_fw, Callable(), Callable())
	add_child(_tree)


## Fills the tree from the catalog again, keeping the search text.
func rebuild() -> void:
	_tree.clear()
	var root := _tree.create_item()
	var folders := {}
	var words := _search.text.to_lower().split(" ", false)
	for entry in BehaviorTaskCatalog.get_entries():
		var haystack := ("%s %s" % [entry["name"], " ".join(entry["category"])]).to_lower()
		var matches := true
		for word in words:
			if not haystack.contains(word):
				matches = false
				break
		if not matches:
			continue
		var parent := root
		var key := ""
		for part in entry["category"]:
			key += "/" + part
			if not folders.has(key):
				var folder := _tree.create_item(parent)
				folder.set_text(0, part)
				folder.set_selectable(0, false)
				folders[key] = folder
			parent = folders[key]
		var item := _tree.create_item(parent)
		item.set_text(0, entry["name"])
		var icon := BehaviorTaskCatalog.get_icon(entry["script"])
		if icon:
			item.set_icon(0, icon)
			item.set_icon_max_width(0, 16)
		item.set_metadata(0, entry)
		item.set_tooltip_text(0, BehaviorTaskCatalog.get_doc(entry["script"]))


func _on_item_activated() -> void:
	var item := _tree.get_selected()
	if item and item.get_metadata(0) is Dictionary:
		task_activated.emit(item.get_metadata(0))


func _get_drag_data_fw(at_position: Vector2) -> Variant:
	var item := _tree.get_item_at_position(at_position)
	if item == null or not (item.get_metadata(0) is Dictionary):
		return null
	var entry: Dictionary = item.get_metadata(0)
	var preview := Label.new()
	preview.text = entry["name"]
	_tree.set_drag_preview(preview)
	return {"type": DRAG_TYPE, "class_name": entry["class_name"]}
