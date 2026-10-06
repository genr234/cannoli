@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceTextureOffset
extends JuiceFeedback
## Scrolls or scales the texture of a node over time, such as a flowing energy bar or a
## pulsing pattern.
##
## SHADER_PARAMETER drives a vec2 uniform of the node's material, so your shader decides what
## offset and scale mean. SPRITE_REGION scrolls or scales the region rectangle of a [Sprite2D]
## or [Sprite3D] (turn on texture repeat on the node to make scrolling wrap).

## Where the offset or scale is applied.
enum Target {
	## A vec2 uniform of the node's [ShaderMaterial].
	SHADER_PARAMETER,
	## The region rectangle of a [Sprite2D] or [Sprite3D].
	SPRITE_REGION,
}
## What changes.
enum Property {
	## The texture position.
	OFFSET,
	## The texture size factor. 1 is the normal size.
	SCALE,
}
## ABSOLUTE blends from the origin toward the value. ADDITIVE adds the value to the origin.
enum Mode { ABSOLUTE, ADDITIVE }

@export_group("Texture")
## Where to apply the change.
@export var texture_target: Target = Target.SHADER_PARAMETER:
	set(value):
		texture_target = value
		notify_property_list_changed()
## Offset or scale.
@export var changes: Property = Property.OFFSET
## How the values are used.
@export var mode: Mode = Mode.ADDITIVE
## Seconds one play takes.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 1.0
## The curve of the animation. Null is a straight line.
@export var tween: JuiceTween
## The value at curve position 0.
@export var from_value: Vector2 = Vector2.ZERO
## The value at curve position 1. For SPRITE_REGION offsets this is in texture pixels.
@export var to_value: Vector2 = Vector2(1.0, 0.0)
@export_group("Material")
## The vec2 uniform to drive for SHADER_PARAMETER.
@export var parameter: StringName = &"uv_offset"
## Edits a private copy of the material, so nodes sharing it do not move too.
@export var duplicate_material: bool = true

var _slot: JuiceMaterialSlot
var _bound_node: Node
var _initial_region := Rect2()
var _initial_region_enabled := false
var _initial_value := Vector2.ZERO
var _origin := Vector2.ZERO


func _validate_property(property_info: Dictionary) -> void:
	super._validate_property(property_info)
	var prop_name: String = property_info.name
	if prop_name in ["parameter", "duplicate_material", "Material"] and texture_target != Target.SHADER_PARAMETER:
		if property_info.usage & PROPERTY_USAGE_GROUP:
			property_info.usage = PROPERTY_USAGE_NONE
		else:
			property_info.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _on_initialize() -> void:
	_bind()


func _on_play(_feedback_intensity: float) -> void:
	_bind()
	if not is_retrigger():
		_origin = _read()
	if duration <= 0.0:
		_apply(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	_apply(progress)


func _on_restore() -> void:
	if not is_instance_valid(_bound_node):
		return
	if texture_target == Target.SPRITE_REGION:
		_bound_node.set("region_rect", _initial_region)
		_bound_node.set("region_enabled", _initial_region_enabled)
	elif _slot != null and _slot.material is ShaderMaterial:
		(_slot.material as ShaderMaterial).set_shader_parameter(parameter, _initial_value)
		_slot.restore()
	_bound_node = null


func _bind() -> void:
	var node := get_target()
	if node == null or node == _bound_node:
		return
	_bound_node = null
	_slot = null
	if texture_target == Target.SPRITE_REGION:
		if not (node is Sprite2D or node is Sprite3D):
			return
		_bound_node = node
		_initial_region = node.get("region_rect")
		_initial_region_enabled = node.get("region_enabled")
		var texture: Texture2D = node.get("texture")
		if _initial_region.size == Vector2.ZERO and texture != null:
			_initial_region = Rect2(Vector2.ZERO, texture.get_size())
	else:
		var slot := JuiceMaterialSlot.new()
		if parameter == &"" or not slot.bind(node, -1, duplicate_material) or not slot.material is ShaderMaterial:
			return
		_slot = slot
		_bound_node = node
		_initial_value = _read_parameter()
	_origin = _read()


func _read() -> Vector2:
	if texture_target == Target.SPRITE_REGION:
		if changes == Property.OFFSET:
			return (_bound_node.get("region_rect") as Rect2).position
		return Vector2.ONE if _initial_region.size == Vector2.ZERO else (_bound_node.get("region_rect") as Rect2).size / _initial_region.size
	return _read_parameter()


func _read_parameter() -> Vector2:
	if _slot == null:
		return Vector2.ZERO
	var shader_material := _slot.material as ShaderMaterial
	var value: Variant = shader_material.get_shader_parameter(parameter)
	if value == null and shader_material.shader != null:
		value = RenderingServer.shader_get_parameter_default(shader_material.shader.get_rid(), parameter)
	return value if value is Vector2 else (Vector2.ONE if changes == Property.SCALE else Vector2.ZERO)


func _apply(progress: float) -> void:
	if not is_instance_valid(_bound_node):
		return
	var shaped := JuiceTween.sample(tween, progress)
	var between := from_value.lerp(to_value, shaped)
	var result: Vector2
	if mode == Mode.ADDITIVE:
		result = _origin + between * get_intensity()
	else:
		result = _origin.lerp(between, get_intensity())
	if texture_target == Target.SPRITE_REGION:
		var rect: Rect2 = _bound_node.get("region_rect")
		_bound_node.set("region_enabled", true)
		if rect.size == Vector2.ZERO:
			rect.size = _initial_region.size
		if changes == Property.OFFSET:
			rect.position = result
		else:
			rect.size = _initial_region.size * result
		_bound_node.set("region_rect", rect)
	elif _slot != null:
		(_slot.material as ShaderMaterial).set_shader_parameter(parameter, result)
