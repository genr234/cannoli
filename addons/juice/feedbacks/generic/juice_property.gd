@tool
@icon("res://addons/juice/icons/transform.svg")
class_name JuiceProperty
extends JuiceFeedback
## Animates any property of any node between two values.
##
## Set [member property_path] to something like [code]Sprite2D:modulate[/code],
## [code]:position:x[/code] or just [code]:rotation[/code]. The part before the first colon
## is the node, relative to the player. With no node part, the target of this feedback is
## used. It supports float, int, Vector2, Vector3, Vector4 and Color properties.
##
## Intensity is the share of the effect that shows. It scales the animated change, so 0 leaves
## the property alone.

## ABSOLUTE blends from the origin to the value between [member from_value] and [member to_value].
## ADDITIVE adds that value to the origin.
enum Mode { ABSOLUTE, ADDITIVE }
## EACH_PLAY takes the origin from the node when a play starts. INITIAL uses the value found
## when the player initialized.
enum Origin { EACH_PLAY, INITIAL }

@export_group("Property")
## The property to animate, as [code]Node:property[/code].
@export var property_path: NodePath = NodePath()
## How the values are used.
@export var mode: Mode = Mode.ABSOLUTE
## Where ADDITIVE and ABSOLUTE start from.
@export var origin: Origin = Origin.EACH_PLAY
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
## The curve of the animation. Null is a straight line.
@export var tween: JuiceTween
## The value at curve position 0. Its type must match the property.
@export var from_value: Variant = 0.0
## The value at curve position 1. Its type must match the property.
@export var to_value: Variant = 1.0

var _node: Node
var _property := NodePath()
var _initial: Variant
var _origin: Variant
var _usable := false


func _get_duration() -> float:
	return duration


func _on_initialize() -> void:
	_usable = false
	_node = null
	if property_path.get_subname_count() == 0:
		push_warning("JuiceProperty: the property path '%s' has no property part." % property_path)
		return
	_node = resolve(property_path) if property_path.get_name_count() > 0 else get_target()
	if _node == null:
		return
	_property = NodePath(property_path.get_concatenated_subnames())
	_initial = _node.get_indexed(_property)
	_origin = _initial
	_usable = _supported_type(typeof(_initial))


func _on_play(_feedback_intensity: float) -> void:
	if not _usable or not is_instance_valid(_node):
		return
	if origin == Origin.INITIAL:
		_origin = _initial
	elif not is_retrigger():
		_origin = _node.get_indexed(_property)
	if duration <= 0.0:
		_apply(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	if _usable and is_instance_valid(_node):
		_apply(progress)


func _on_restore() -> void:
	if _usable and is_instance_valid(_node):
		_node.set_indexed(_property, _initial)


func _apply(progress: float) -> void:
	var curve_value := JuiceTween.sample(tween, progress)
	var from_v := _coerce(from_value)
	var to_v := _coerce(to_value)
	var shaped: Variant = Juice.mix(from_v, to_v, curve_value)
	var result: Variant
	if mode == Mode.ADDITIVE:
		result = Juice.add_values(_origin, Juice.scale_value(shaped, get_intensity()))
	else:
		result = Juice.mix(_origin, shaped, get_intensity())
	if typeof(_initial) == TYPE_INT:
		result = roundi(float(result))
	_node.set_indexed(_property, result)


# Floats and ints may be mixed in the inspector, so convert to the property's type.
func _coerce(value: Variant) -> Variant:
	var wanted := typeof(_initial)
	if typeof(value) == wanted:
		return value
	if (wanted == TYPE_FLOAT or wanted == TYPE_INT) and (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT):
		return float(value)
	return _initial


func _supported_type(type: int) -> bool:
	return type in [TYPE_FLOAT, TYPE_INT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR]
