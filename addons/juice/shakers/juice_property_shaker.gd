@tool
@icon("res://addons/juice/icons/shaker.svg")
class_name JuicePropertyShaker
extends JuiceShaker
## Shakes any number, vector or color property of any node with a curve.
##
## It is the generic shaker: put one next to a [Light3D] and shake [code]light_energy[/code],
## on an [AudioStreamPlayer] and shake [code]pitch_scale[/code], on a sprite and shake
## [code]modulate[/code]. Listens to [code]juice_property_shake[/code], sent by [JuicePropertyShake].
##
## Over the shake the curve value picks a point between [member remap_zero] and [member remap_one].
## With [member relative] that point is added to the property. Without it the property moves to
## that point and comes back at the end. Either way the shaker only adds an offset, so it stacks
## with other shakers on the same property.
##
## Payload keys: [code]duration[/code], [code]curve[/code] ([Curve] or null for a bump),
## [code]remap_zero[/code], [code]remap_one[/code], [code]relative[/code], [code]amount[/code]
## (share of the effect).

const EVENT := &"juice_property_shake"

@export_group("Property")
## The property to shake, as [code]Node:property[/code]. The node is relative to this shaker. With no
## node part, the target (the parent by default) is used. [code]Sprite2D:modulate:a[/code] works too.
@export var property_path: NodePath = NodePath()
## The curve over the shake. Empty is a bump that rises and falls.
@export var curve: Curve
## The value at curve value 0. Its type must match the property.
@export var remap_zero: Variant = 0.0
## The value at curve value 1. Its type must match the property.
@export var remap_one: Variant = 1.0
## Adds the remapped value to the property instead of moving the property to it.
@export var relative: bool = false

var _p_curve: Curve
var _p_zero: Variant
var _p_one: Variant
var _p_relative: bool = false
var _p_amount: float = 1.0
var _start: Variant


func _init() -> void:
	shake_duration = 0.3


func _get_events() -> Array[StringName]:
	return [EVENT]


func get_target_node() -> Node:
	if property_path.get_name_count() > 0:
		return get_node_or_null(NodePath(property_path.get_concatenated_names()))
	return super.get_target_node()


func _get_property_name() -> String:
	return property_path.get_concatenated_subnames()


func _is_target_supported(node: Node) -> bool:
	var property := _get_property_name()
	if property.is_empty():
		return false
	var value: Variant = node.get_indexed(NodePath(property))
	return typeof(value) in [TYPE_FLOAT, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR]


func _on_begin(_event: StringName, payload: Dictionary, reach: float) -> bool:
	var node := get_target_node()
	_start = get_base_value(node, _get_property_name())
	_p_curve = payload.get("curve", curve)
	_p_zero = _coerce(payload.get("remap_zero", remap_zero))
	_p_one = _coerce(payload.get("remap_one", remap_one))
	_p_relative = bool(payload.get("relative", relative))
	_p_amount = float(payload.get("amount", 1.0)) * reach
	_run_permanent = false
	return true


func _shake(progress: float, _seconds: float) -> void:
	var node := get_target_node()
	if node == null:
		return
	var along := sample_bump(_p_curve, progress)
	var value: Variant = Juice.mix(_p_zero, _p_one, along)
	var offset: Variant = value
	if not _p_relative:
		offset = Juice.add_values(value, Juice.scale_value(_start, -1.0))
	set_offset(node, _get_property_name(), Juice.scale_value(offset, _p_amount))


# Numbers may be mixed in the inspector, so convert to the type of the property.
func _coerce(value: Variant) -> Variant:
	var wanted := typeof(_start)
	if typeof(value) == wanted:
		return value
	if wanted == TYPE_FLOAT and typeof(value) == TYPE_INT:
		return float(value)
	return _start
