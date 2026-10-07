@tool
extends EditorProperty
## Replaces the editor of a bound property with the name of its variable and a button
## that removes the binding.

var _label := Label.new()
var _button := Button.new()


func _init(variable_name: String, unbind: Callable) -> void:
	var row := HBoxContainer.new()
	_label.text = "→ %s" % variable_name
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.clip_text = true
	_label.add_theme_color_override("font_color", Color("8fcf6b"))
	_label.tooltip_text = "Bound to the variable \"%s\". The task reads and writes it instead of its own value." % variable_name
	_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(_label)
	_button.text = "Unbind"
	_button.tooltip_text = "Use the value of the property again."
	_button.pressed.connect(unbind)
	row.add_child(_button)
	add_child(row)
	add_focusable(_button)
