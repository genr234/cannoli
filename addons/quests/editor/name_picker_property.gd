@tool
extends EditorProperty
## Picks a string from a list that is computed when the inspector refreshes,
## such as a counter, node id or quest id. A value that is not in the list is
## kept and marked as missing. An optional first entry stands for the empty string.

var _get_options: Callable
var _empty_label: String
var _button := OptionButton.new()


## `get_options` returns a PackedStringArray. `empty_label` is the text for the
## empty value, or "" if the empty value is not a valid choice.
func _init(get_options: Callable, empty_label := "") -> void:
	_get_options = get_options
	_empty_label = empty_label
	_button.clip_text = true
	_button.item_selected.connect(_on_item_selected)
	add_child(_button)
	add_focusable(_button)


func _update_property() -> void:
	var current: String = get_edited_object().get(get_edited_property())
	var options: PackedStringArray = _get_options.call()
	_button.clear()
	if not _empty_label.is_empty():
		_button.add_item(_empty_label)
		_button.set_item_metadata(0, "")
	for option in options:
		_button.add_item(option)
		_button.set_item_metadata(_button.item_count - 1, option)
	var selected := -1
	for index in _button.item_count:
		if _button.get_item_metadata(index) == current:
			selected = index
	if selected < 0:
		_button.add_item("%s (missing)" % current if not current.is_empty() else "(none)")
		_button.set_item_metadata(_button.item_count - 1, current)
		selected = _button.item_count - 1
	_button.select(selected)
	_button.disabled = is_read_only()


func _on_item_selected(index: int) -> void:
	emit_changed(get_edited_property(), _button.get_item_metadata(index))
