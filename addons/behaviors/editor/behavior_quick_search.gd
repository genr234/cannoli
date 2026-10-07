@tool
extends PopupPanel
## A search box with a list of tasks. Enter picks the highlighted task.

## A task was picked. [param entry] comes from [method BehaviorTaskCatalog.get_entries].
signal chosen(entry: Dictionary)

var _search := LineEdit.new()
var _list := ItemList.new()
var _shown: Array[Dictionary] = []
var _only_parents := false


func _init() -> void:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(300, 320)
	add_child(box)
	_search.placeholder_text = "Search tasks..."
	_search.clear_button_enabled = true
	_search.text_changed.connect(func(_text: String) -> void: _refill())
	_search.text_submitted.connect(func(_text: String) -> void: _pick_selected())
	_search.gui_input.connect(_on_search_input)
	box.add_child(_search)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_activated.connect(func(_index: int) -> void: _pick_selected())
	box.add_child(_list)


## Opens the popup at [param screen_position]. With [param only_parents] only tasks
## that can hold children are listed.
func open_at(screen_position: Vector2i, only_parents := false) -> void:
	_only_parents = only_parents
	_search.text = ""
	_refill()
	position = screen_position
	popup()
	_search.grab_focus()


func _refill() -> void:
	_list.clear()
	_shown.clear()
	var words := _search.text.to_lower().split(" ", false)
	for entry in BehaviorTaskCatalog.get_entries():
		if _only_parents and entry["kind"] != "composite" and entry["kind"] != "decorator":
			continue
		var haystack := ("%s %s" % [entry["name"], " ".join(entry["category"])]).to_lower()
		var matches := true
		for word in words:
			if not haystack.contains(word):
				matches = false
				break
		if not matches:
			continue
		var icon := BehaviorTaskCatalog.get_icon(entry["script"])
		_list.add_item("%s   (%s)" % [entry["name"], " / ".join(entry["category"])], icon)
		_list.set_item_tooltip(_list.item_count - 1, BehaviorTaskCatalog.get_doc(entry["script"]))
		_shown.append(entry)
	if _list.item_count > 0:
		_list.select(0)


func _on_search_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed:
		return
	if key.keycode == KEY_DOWN or key.keycode == KEY_UP:
		var count := _list.item_count
		if count == 0:
			return
		var selected := _list.get_selected_items()
		var index: int = selected[0] if not selected.is_empty() else -1
		index = clampi(index + (1 if key.keycode == KEY_DOWN else -1), 0, count - 1)
		_list.select(index)
		_list.ensure_current_is_visible()
		_search.accept_event()


func _pick_selected() -> void:
	var selected := _list.get_selected_items()
	if selected.is_empty():
		return
	var entry := _shown[selected[0]]
	hide()
	chosen.emit(entry)
