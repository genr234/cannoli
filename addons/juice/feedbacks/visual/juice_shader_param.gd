@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceShaderParam
extends JuiceFeedback
## Animates a shader parameter of a node's material, or swaps the material over time.
##
## It works on a [CanvasItem] (including [Control]) and on a [GeometryInstance3D]. With
## [constant Source.MATERIAL] the parameter is read from the material. A
## [ShaderMaterial] uses its shader uniforms, other materials use their properties, such as
## [code]albedo_color[/code]. With [constant Source.INSTANCE_UNIFORM] it sets an instance uniform of a 3D
## node, which never touches shared materials. By default a private copy of the material is
## used, so other nodes that share it are left alone.

## What the feedback does.
enum Action {
	## Blends a parameter between two values.
	ANIMATE_PARAMETER,
	## Steps through a list of materials during the play.
	SWAP_MATERIAL,
}
## Where the parameter lives.
enum Source {
	## A uniform or property of the node's material.
	MATERIAL,
	## An instance uniform of a 3D node.
	INSTANCE_UNIFORM,
}
## The type of the parameter.
enum ValueType { FLOAT, VECTOR2, VECTOR3, VECTOR4, COLOR }
## ABSOLUTE blends from the origin toward the value. ADDITIVE adds the value to the origin.
enum Mode { ABSOLUTE, ADDITIVE }

@export_group("Shader Parameter")
## Animate a parameter, or swap the material.
@export var action: Action = Action.ANIMATE_PARAMETER:
	set(value):
		action = value
		notify_property_list_changed()
## Seconds one play takes.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
## The curve of the animation. Null is a straight line.
@export var tween: JuiceTween
## Where the parameter lives.
@export var source: Source = Source.MATERIAL
## The name of the uniform or property.
@export var parameter: StringName = &""
## The type of the parameter.
@export var value_type: ValueType = ValueType.FLOAT:
	set(value):
		value_type = value
		notify_property_list_changed()
## How the values are used.
@export var mode: Mode = Mode.ABSOLUTE
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
@export_group("Material")
## Edits a private copy of the material, so nodes sharing it are not changed.
@export var duplicate_material: bool = true
## The mesh surface to use on a [MeshInstance3D]. -1 uses the material override.
@export var surface: int = -1
@export_group("Swap Material")
## The materials to step through, in order, during the play.
@export var materials: Array[Material] = []
## Puts the original material back when the play ends.
@export var revert_when_finished: bool = true

var _slot: JuiceMaterialSlot
var _bound_node: Node
var _initial: Variant
var _origin: Variant
var _applied_index := -1


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	var animate := action == Action.ANIMATE_PARAMETER
	var hidden := false
	match prop_name:
		"source", "parameter", "value_type", "mode":
			hidden = not animate
		"from_float", "to_float":
			hidden = not animate or value_type != ValueType.FLOAT
		"from_vector", "to_vector":
			hidden = not animate or value_type == ValueType.FLOAT or value_type == ValueType.COLOR
		"from_color", "to_color":
			hidden = not animate or value_type != ValueType.COLOR
		"materials", "revert_when_finished", "Swap Material":
			hidden = animate
	if hidden:
		if property.usage & PROPERTY_USAGE_GROUP:
			property.usage = PROPERTY_USAGE_NONE
		else:
			property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _on_initialize() -> void:
	_bind()


func _on_play(_feedback_intensity: float) -> void:
	_bind()
	_applied_index = -1
	if action == Action.ANIMATE_PARAMETER and not is_retrigger():
		_origin = _read()
		if _origin == null:
			_origin = _initial
	if duration <= 0.0:
		_apply(0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	_apply(progress)


func _on_finished() -> void:
	if action == Action.SWAP_MATERIAL and revert_when_finished and _slot != null:
		_slot.restore()
		_applied_index = -1


func _on_restore() -> void:
	var node := get_target()
	if _slot != null:
		if action == Action.ANIMATE_PARAMETER and _initial != null:
			_write(_initial)
		_slot.restore()
	elif action == Action.ANIMATE_PARAMETER and is_instance_valid(node) and _initial != null:
		_write(_initial)
	_bound_node = null


func _bind() -> void:
	var node := get_target()
	if node == null or node == _bound_node:
		return
	if _slot != null:
		_slot.restore()
	_bound_node = node
	_slot = null
	if not (node is CanvasItem or node is GeometryInstance3D):
		return
	if action == Action.SWAP_MATERIAL:
		_slot = JuiceMaterialSlot.new()
		_slot.bind(node, surface, false)
		return
	if source == Source.INSTANCE_UNIFORM:
		if not node is GeometryInstance3D:
			return
		_initial = _read()
		return
	_slot = JuiceMaterialSlot.new()
	if not _slot.bind(node, surface, duplicate_material):
		_slot = null
		return
	_initial = _read()


func _apply(progress: float) -> void:
	if _slot == null and not (source == Source.INSTANCE_UNIFORM and is_instance_valid(_bound_node)):
		return
	if action == Action.SWAP_MATERIAL:
		_swap(progress)
		return
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
	_write(result)


func _swap(progress: float) -> void:
	if materials.is_empty() or _slot == null:
		return
	var index := mini(floori(clampf(progress, 0.0, 1.0) * materials.size()), materials.size() - 1)
	if index == _applied_index:
		return
	_applied_index = index
	_slot.assign(materials[index])


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


func _read() -> Variant:
	if parameter == &"" or not is_instance_valid(_bound_node):
		return null
	if source == Source.INSTANCE_UNIFORM:
		if _bound_node is GeometryInstance3D:
			return (_bound_node as GeometryInstance3D).get_instance_shader_parameter(parameter)
		return null
	if _slot == null or _slot.material == null:
		return null
	var material := _slot.material
	if material is ShaderMaterial:
		var shader_material := material as ShaderMaterial
		var value: Variant = shader_material.get_shader_parameter(parameter)
		if value == null and shader_material.shader != null:
			value = RenderingServer.shader_get_parameter_default(shader_material.shader.get_rid(), parameter)
		return value
	return material.get(parameter)


func _write(value: Variant) -> void:
	if parameter == &"" or not is_instance_valid(_bound_node):
		return
	if source == Source.INSTANCE_UNIFORM:
		if _bound_node is GeometryInstance3D:
			(_bound_node as GeometryInstance3D).set_instance_shader_parameter(parameter, value)
		return
	if _slot == null or _slot.material == null:
		return
	if _slot.material is ShaderMaterial:
		(_slot.material as ShaderMaterial).set_shader_parameter(parameter, value)
	else:
		_slot.material.set(parameter, value)
