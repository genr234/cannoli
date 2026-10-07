@tool
@icon("res://addons/behaviors/icons/variable.svg")
class_name BehaviorClampVariable
extends BehaviorAction
## Keeps a number, vector or color inside a range. Vectors and colors are clamped
## part by part.

## The variable to clamp.
@export var variable: String = ""
## The lowest allowed value.
@export var min_value: float = 0.0
## The highest allowed value.
@export var max_value: float = 1.0


func _on_update(_delta: float) -> Status:
	if variable.is_empty():
		return Status.FAILURE
	var current: Variant = get_var(StringName(variable))
	var low := minf(min_value, max_value)
	var high := maxf(min_value, max_value)
	var result: Variant
	match typeof(current):
		TYPE_INT:
			result = clampi(current, int(ceilf(low)), int(floorf(high)))
		TYPE_FLOAT:
			result = clampf(current, low, high)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR:
			result = current
			for index in _parts(current):
				result[index] = clampf(result[index], low, high)
		TYPE_VECTOR2I, TYPE_VECTOR3I, TYPE_VECTOR4I:
			result = current
			for index in _parts(current):
				result[index] = clampi(result[index], int(ceilf(low)), int(floorf(high)))
		_:
			return Status.FAILURE
	set_var(StringName(variable), result)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if variable.is_empty():
		warnings.append("Clamp Variable has no variable.")
	return warnings


func _get_graph_text() -> String:
	return "%s in %s–%s" % [variable, min_value, max_value]


func _parts(vector: Variant) -> int:
	match typeof(vector):
		TYPE_VECTOR2, TYPE_VECTOR2I: return 2
		TYPE_VECTOR3, TYPE_VECTOR3I: return 3
	return 4
