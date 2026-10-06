@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceShaderGlobal
extends JuiceFeedback
## Animates a global shader parameter, which every shader that declares it reacts to.
##
## Declare the parameter under Project Settings > Shader Globals first. This is handy for
## screen-wide looks, such as a world desaturation amount or a pulse that many materials share.
## The value goes back to what it was when the feedback is restored.

## The type of the global parameter.
enum ValueType { FLOAT, VECTOR2, VECTOR3, VECTOR4, COLOR }
## ABSOLUTE blends from the origin toward the value. ADDITIVE adds the value to the origin.
enum Mode { ABSOLUTE, ADDITIVE }

@export_group("Shader Global")
## The name of the global parameter, without the prefix.
@export var parameter: StringName = &""
## The type of the parameter.
@export var value_type: ValueType = ValueType.FLOAT:
	set(value):
		value_type = value
		notify_property_list_changed()
## How the values are used.
@export var mode: Mode = Mode.ABSOLUTE
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
## The curve of the animation. Null is a straight line.
@export var tween: JuiceTween
## The value at curve position 0 for a float parameter.
@export var from_float: float = 0.0
## The value at curve position 1 for a float parameter.
@export var to_float: float = 1.0
## The value at curve position 0 for a vector parameter. Unused components are ignored.
@export var from_vector: Vector4 = Vector4.ZERO
## The value at curve position 1 for a vector parameter. Unused components are ignored.
@export var to_vector: Vector4 = Vector4.ONE
## The value at curve position 0 for a color parameter.
@export var from_color: Color = Color.WHITE
## The value at curve position 1 for a color parameter.
@export var to_color: Color = Color.RED

var _initial: Variant
var _origin: Variant


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	var hidden := false
	match prop_name:
		"from_float", "to_float":
			hidden = value_type != ValueType.FLOAT
		"from_vector", "to_vector":
			hidden = value_type == ValueType.FLOAT or value_type == ValueType.COLOR
		"from_color", "to_color":
			hidden = value_type != ValueType.COLOR
	if hidden:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _has_target() -> bool:
	return false


func _on_initialize() -> void:
	_initial = _read()
	_origin = _initial


func _on_play(_feedback_intensity: float) -> void:
	if not is_retrigger():
		_origin = _read()
		if _origin == null:
			_origin = _initial
	if duration <= 0.0:
		_apply(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	_apply(progress)


func _on_restore() -> void:
	if _initial != null and parameter != &"":
		RenderingServer.global_shader_parameter_set(parameter, _initial)


func _apply(progress: float) -> void:
	if parameter == &"":
		return
	var shaped := JuiceTween.sample(tween, progress)
	var between: Variant = Juice.mix(_from(), _to(), shaped)
	var origin: Variant = _origin if _origin != null else _from()
	if typeof(origin) == TYPE_INT:
		origin = float(origin)
	if typeof(origin) != typeof(between):
		return
	var result: Variant
	if mode == Mode.ADDITIVE:
		result = Juice.add_values(origin, Juice.scale_value(between, get_intensity()))
	else:
		result = Juice.mix(origin, between, get_intensity())
	RenderingServer.global_shader_parameter_set(parameter, result)


func _read() -> Variant:
	if parameter == &"":
		return null
	return RenderingServer.global_shader_parameter_get(parameter)


func _from() -> Variant:
	match value_type:
		ValueType.FLOAT:
			return from_float
		ValueType.VECTOR2:
			return Vector2(from_vector.x, from_vector.y)
		ValueType.VECTOR3:
			return Vector3(from_vector.x, from_vector.y, from_vector.z)
		ValueType.VECTOR4:
			return from_vector
	return from_color


func _to() -> Variant:
	match value_type:
		ValueType.FLOAT:
			return to_float
		ValueType.VECTOR2:
			return Vector2(to_vector.x, to_vector.y)
		ValueType.VECTOR3:
			return Vector3(to_vector.x, to_vector.y, to_vector.z)
		ValueType.VECTOR4:
			return to_vector
	return to_color
