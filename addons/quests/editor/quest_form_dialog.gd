@tool
extends ConfirmationDialog
## Builds a small form from a field list (see QuestWizards) and reports the
## values when the user confirms.

var _fields: Array = []
var _controls: Dictionary = {}
var _on_accept: Callable
var _help := Label.new()
var _grid := GridContainer.new()


func _init() -> void:
	min_size = Vector2(520, 0)
	ok_button_text = "Add"
	var box := VBoxContainer.new()
	_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_help.custom_minimum_size.x = 480
	box.add_child(_help)
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 12)
	box.add_child(_grid)
	add_child(box)
	confirmed.connect(_on_confirmed)


## Shows the dialog. `on_accept` receives a dictionary of key -> value.
func open(dialog_title: String, help: String, fields: Array, on_accept: Callable, accept_text := "Add", initial: Dictionary = {}) -> void:
	title = dialog_title
	ok_button_text = accept_text
	_help.text = help
	_fields = fields
	_on_accept = on_accept
	_controls.clear()
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for field: Dictionary in fields:
		var label := Label.new()
		label.text = field.label
		label.tooltip_text = field.tooltip
		_grid.add_child(label)
		var value: Variant = initial.get(field.key, field.default)
		var control: Control
		match field.type:
			"bool":
				control = CheckBox.new()
				control.button_pressed = value
			"int":
				control = SpinBox.new()
				control.allow_greater = true
				control.allow_lesser = true
				control.value = value
			_:
				control = LineEdit.new()
				control.text = str(value)
				control.custom_minimum_size.x = 320
		control.tooltip_text = field.tooltip
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_grid.add_child(control)
		_controls[field.key] = control
	reset_size()
	popup_centered()


func _on_confirmed() -> void:
	var values := {}
	for field: Dictionary in _fields:
		var control: Control = _controls[field.key]
		match field.type:
			"bool":
				values[field.key] = (control as CheckBox).button_pressed
			"int":
				values[field.key] = int((control as SpinBox).value)
			_:
				values[field.key] = (control as LineEdit).text
	_on_accept.call(values)
