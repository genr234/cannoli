@tool
extends EditorProperty
## Edits the id of a message sender or target. The field is only used when the
## participant specifier next to it is set to Other, so it is disabled
## otherwise. A menu lists the quest ids of identities in the edited scene.

var _specifier_property: String
var _get_ids: Callable
var _box := HBoxContainer.new()
var _line := LineEdit.new()
var _menu := MenuButton.new()
var _updating := false


func _init(specifier_property: String, get_ids: Callable) -> void:
	_specifier_property = specifier_property
	_get_ids = get_ids
	_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line.text_submitted.connect(func(_t: String) -> void: _commit())
	_line.focus_exited.connect(_commit)
	_menu.text = "IDs"
	_menu.flat = false
	_menu.about_to_popup.connect(_fill_menu)
	_menu.get_popup().index_pressed.connect(func(index: int) -> void:
		_line.text = _menu.get_popup().get_item_text(index)
		_commit())
	_box.add_child(_line)
	_box.add_child(_menu)
	add_child(_box)
	add_focusable(_line)


func _update_property() -> void:
	var object := get_edited_object()
	var specifier: int = object.get(_specifier_property) if _specifier_property in object else QuestMessages.Participant.OTHER
	var uses_id := specifier == QuestMessages.Participant.OTHER or specifier == QuestMessages.Participant.ANY
	_updating = true
	_line.text = object.get(get_edited_property())
	_line.placeholder_text = "any" if specifier == QuestMessages.Participant.ANY else "entity id"
	_line.editable = uses_id and not is_read_only()
	_menu.disabled = not uses_id or is_read_only()
	_line.tooltip_text = "" if uses_id else "Not used: the participant is %s." % QuestMessages.Participant.keys()[specifier].capitalize()
	_updating = false


func _fill_menu() -> void:
	var popup := _menu.get_popup()
	popup.clear()
	var ids: PackedStringArray = _get_ids.call()
	for id in ids:
		popup.add_item(id)
	if ids.is_empty():
		popup.add_item("(no identities in this scene)")
		popup.set_item_disabled(0, true)


func _commit() -> void:
	if not _updating and _line.text != get_edited_object().get(get_edited_property()):
		emit_changed(get_edited_property(), _line.text)
