@tool
extends EditorProperty
## Picks several strings, such as quest ids or node ids, for a
## PackedStringArray property. Values that are not in the list are kept.

var _get_options: Callable
var _exclude: String
var _button := MenuButton.new()


## `exclude` is left out of the list, such as the quest's own id.
func _init(get_options: Callable, exclude := "") -> void:
	_get_options = get_options
	_exclude = exclude
	_button.clip_text = true
	_button.flat = false
	_button.about_to_popup.connect(_fill_menu)
	_button.get_popup().hide_on_checkable_item_selection = false
	_button.get_popup().index_pressed.connect(_on_index_pressed)
	add_child(_button)
	add_focusable(_button)


func _update_property() -> void:
	var current: PackedStringArray = get_edited_object().get(get_edited_property())
	_button.text = ", ".join(current) if not current.is_empty() else "(none)"
	_button.disabled = is_read_only()


func _fill_menu() -> void:
	var current: PackedStringArray = get_edited_object().get(get_edited_property())
	var popup := _button.get_popup()
	popup.clear()
	var options: PackedStringArray = _get_options.call()
	for option in options:
		if option != _exclude:
			popup.add_check_item(option)
			popup.set_item_checked(popup.item_count - 1, current.has(option))
	for value in current:
		if not options.has(value):
			popup.add_check_item("%s (missing)" % value)
			popup.set_item_metadata(popup.item_count - 1, value)
			popup.set_item_checked(popup.item_count - 1, true)


func _on_index_pressed(index: int) -> void:
	var popup := _button.get_popup()
	popup.set_item_checked(index, not popup.is_item_checked(index))
	var values := PackedStringArray()
	for item in popup.item_count:
		if popup.is_item_checked(item):
			var meta: Variant = popup.get_item_metadata(item)
			values.append(meta if meta is String else popup.get_item_text(item))
	emit_changed(get_edited_property(), values)
