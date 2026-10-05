@tool
extends EditorProperty
## Edits a QuestMessageValue inline: nothing, an integer or a string. Every
## change assigns a new value so it goes through undo.

const TYPE_NAMES: PackedStringArray = ["Any / none", "Integer", "String"]

var _box := HBoxContainer.new()
var _type := OptionButton.new()
var _int := SpinBox.new()
var _text := LineEdit.new()
var _create := Button.new()
var _updating := false


func _init() -> void:
	for type_name in TYPE_NAMES:
		_type.add_item(type_name)
	_type.item_selected.connect(func(_i: int) -> void: _commit())
	_int.allow_greater = true
	_int.allow_lesser = true
	_int.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_int.value_changed.connect(func(_v: float) -> void: _commit())
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.placeholder_text = "value"
	_text.text_submitted.connect(func(_t: String) -> void: _commit())
	_text.focus_exited.connect(_commit)
	_create.text = "Set value"
	_create.pressed.connect(func() -> void: emit_changed(get_edited_property(), QuestMessageValue.new()))
	for control in [_create, _type, _int, _text]:
		_box.add_child(control)
	add_child(_box)
	add_focusable(_type)
	add_focusable(_int)
	add_focusable(_text)


func _update_property() -> void:
	var value: QuestMessageValue = get_edited_object().get(get_edited_property())
	_updating = true
	_create.visible = value == null
	_type.visible = value != null
	_int.visible = value != null and value.value_type == QuestMessageValue.ValueType.INT
	_text.visible = value != null and value.value_type == QuestMessageValue.ValueType.STRING
	if value != null:
		_type.select(value.value_type)
		_int.value = value.int_value
		_text.text = value.string_value
	_type.disabled = is_read_only()
	_create.disabled = is_read_only()
	_int.editable = not is_read_only()
	_text.editable = not is_read_only()
	_updating = false


func _commit() -> void:
	if _updating:
		return
	var value := QuestMessageValue.new()
	value.value_type = _type.selected as QuestMessageValue.ValueType
	value.int_value = int(_int.value)
	value.string_value = _text.text
	emit_changed(get_edited_property(), value)
