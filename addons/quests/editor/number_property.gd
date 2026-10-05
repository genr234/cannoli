@tool
extends EditorProperty
## Edits a QuestNumber inline: a literal, or a counter's value, minimum or
## maximum. Every change assigns a new QuestNumber so it goes through undo.

const TYPE_NAMES: PackedStringArray = ["Literal", "Counter Value", "Counter Min", "Counter Max"]

var _get_counters: Callable
var _box := HBoxContainer.new()
var _type := OptionButton.new()
var _literal := SpinBox.new()
var _counter_pick := OptionButton.new()
var _counter_text := LineEdit.new()
var _create := Button.new()
var _updating := false


func _init(get_counters: Callable) -> void:
	_get_counters = get_counters
	for type_name in TYPE_NAMES:
		_type.add_item(type_name)
	_type.item_selected.connect(func(_i: int) -> void: _commit())
	_literal.allow_greater = true
	_literal.allow_lesser = true
	_literal.step = 1
	_literal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_literal.value_changed.connect(func(_v: float) -> void: _commit())
	_counter_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter_pick.clip_text = true
	_counter_pick.item_selected.connect(func(_i: int) -> void: _commit())
	_counter_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter_text.placeholder_text = "counter name"
	_counter_text.text_submitted.connect(func(_t: String) -> void: _commit())
	_counter_text.focus_exited.connect(_commit)
	_create.text = "Set value"
	_create.pressed.connect(_on_create_pressed)
	for control in [_create, _type, _literal, _counter_pick, _counter_text]:
		_box.add_child(control)
	add_child(_box)
	add_focusable(_type)
	add_focusable(_literal)
	add_focusable(_counter_pick)
	add_focusable(_counter_text)


func _update_property() -> void:
	var number: QuestNumber = get_edited_object().get(get_edited_property())
	_updating = true
	var counters: PackedStringArray = _get_counters.call()
	_create.visible = number == null
	_type.visible = number != null
	var is_literal := number == null or number.value_type == QuestNumber.ValueType.LITERAL
	_literal.visible = number != null and is_literal
	_counter_pick.visible = number != null and not is_literal and not counters.is_empty()
	_counter_text.visible = number != null and not is_literal and counters.is_empty()
	if number != null:
		_type.select(number.value_type)
		_literal.value = number.literal_value
		_counter_text.text = number.counter_name
		_counter_pick.clear()
		var selected := -1
		for counter_name in counters:
			_counter_pick.add_item(counter_name)
			if counter_name == number.counter_name:
				selected = _counter_pick.item_count - 1
		if selected < 0 and not number.counter_name.is_empty():
			_counter_pick.add_item("%s (missing)" % number.counter_name)
			_counter_pick.set_item_metadata(_counter_pick.item_count - 1, number.counter_name)
			selected = _counter_pick.item_count - 1
		_counter_pick.select(selected)
	for control: Control in [_type, _literal, _counter_pick, _counter_text, _create]:
		if control is Button:
			control.disabled = is_read_only()
	_literal.editable = not is_read_only()
	_counter_text.editable = not is_read_only()
	_updating = false


func _on_create_pressed() -> void:
	emit_changed(get_edited_property(), QuestNumber.literal(0))


func _commit() -> void:
	if _updating:
		return
	var number := QuestNumber.new()
	number.value_type = _type.selected as QuestNumber.ValueType
	number.literal_value = int(_literal.value)
	if _counter_pick.visible and _counter_pick.selected >= 0:
		var meta: Variant = _counter_pick.get_item_metadata(_counter_pick.selected)
		number.counter_name = meta if meta is String else _counter_pick.get_item_text(_counter_pick.selected)
	else:
		number.counter_name = _counter_text.text
	emit_changed(get_edited_property(), number)
