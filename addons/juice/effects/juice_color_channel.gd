class_name JuiceColorChannel
extends RefCounted
## Reads and writes "the color" of a node, whatever kind of node it is.
##
## Without a parameter name it picks the natural color: modulate of a [CanvasItem],
## [Sprite3D] or [Label3D], color of lights, albedo (or emission) of the material of a
## 3D node. With a parameter name it drives that uniform of the node's [ShaderMaterial],
## or an instance uniform of a [GeometryInstance3D]. [method restore] returns the
## color to what [method bind] found, and puts back replaced materials.

enum _Kind { NONE, PROPERTY, MATERIAL_ALBEDO, MATERIAL_EMISSION, SHADER_PARAMETER, INSTANCE_PARAMETER }

## The color found when the channel was bound.
var initial: Color = Color.WHITE

var _kind: _Kind = _Kind.NONE
var _node: Node
var _property: StringName = &""
var _parameter: StringName = &""
var _slot: JuiceMaterialSlot
var _initial_emission_enabled := false


## Binds to [param target]. [param use_instance] makes [param parameter] an instance uniform.
## [param self_modulate] picks self_modulate on canvas items. [param emission] drives the
## emission of a 3D material instead of albedo. Returns false when nothing can be driven.
func bind(target: Node, parameter: StringName = &"", use_instance: bool = false, self_modulate: bool = false, emission: bool = false, duplicate_material: bool = true) -> bool:
	_kind = _Kind.NONE
	_node = target
	_parameter = parameter
	_slot = null
	if target == null:
		return false
	if parameter != &"":
		if use_instance and target is GeometryInstance3D:
			_kind = _Kind.INSTANCE_PARAMETER
			var value: Variant = (target as GeometryInstance3D).get_instance_shader_parameter(parameter)
			initial = value if value is Color else Color.WHITE
			return true
		_slot = JuiceMaterialSlot.new()
		if _slot.bind(target, -1, duplicate_material) and _slot.material is ShaderMaterial:
			_kind = _Kind.SHADER_PARAMETER
			var shader_material := _slot.material as ShaderMaterial
			var found: Variant = shader_material.get_shader_parameter(parameter)
			if not found is Color and shader_material.shader != null:
				found = RenderingServer.shader_get_parameter_default(shader_material.shader.get_rid(), parameter)
			initial = found if found is Color else Color.WHITE
			return true
		_slot = null
		return false
	if target is Light2D:
		_property = &"color"
	elif target is Light3D:
		_property = &"light_color"
	elif target is CanvasItem:
		_property = &"self_modulate" if self_modulate else &"modulate"
	elif target is Sprite3D or target is Label3D:
		_property = &"modulate"
	if _property != &"":
		_kind = _Kind.PROPERTY
		initial = target.get(_property)
		return true
	if target is GeometryInstance3D:
		_slot = JuiceMaterialSlot.new()
		if _slot.bind(target, -1, duplicate_material) and _slot.material is BaseMaterial3D:
			var base := _slot.material as BaseMaterial3D
			if emission:
				_kind = _Kind.MATERIAL_EMISSION
				initial = base.emission
				_initial_emission_enabled = base.emission_enabled
			else:
				_kind = _Kind.MATERIAL_ALBEDO
				initial = base.albedo_color
			return true
		_slot = null
	return false


## True when something can be driven.
func is_bound() -> bool:
	return _kind != _Kind.NONE and is_instance_valid(_node)


## The color right now.
func read() -> Color:
	if not is_bound():
		return initial
	match _kind:
		_Kind.PROPERTY:
			return _node.get(_property)
		_Kind.MATERIAL_ALBEDO:
			return (_slot.material as BaseMaterial3D).albedo_color
		_Kind.MATERIAL_EMISSION:
			return (_slot.material as BaseMaterial3D).emission
		_Kind.SHADER_PARAMETER:
			var value: Variant = (_slot.material as ShaderMaterial).get_shader_parameter(_parameter)
			return value if value is Color else initial
		_Kind.INSTANCE_PARAMETER:
			var instance_value: Variant = (_node as GeometryInstance3D).get_instance_shader_parameter(_parameter)
			return instance_value if instance_value is Color else initial
	return initial


## Sets the color.
func write(color: Color) -> void:
	if not is_bound():
		return
	match _kind:
		_Kind.PROPERTY:
			_node.set(_property, color)
		_Kind.MATERIAL_ALBEDO:
			(_slot.material as BaseMaterial3D).albedo_color = color
		_Kind.MATERIAL_EMISSION:
			var base := _slot.material as BaseMaterial3D
			base.emission_enabled = true
			base.emission = color
		_Kind.SHADER_PARAMETER:
			(_slot.material as ShaderMaterial).set_shader_parameter(_parameter, color)
		_Kind.INSTANCE_PARAMETER:
			(_node as GeometryInstance3D).set_instance_shader_parameter(_parameter, color)


## Writes the color found when bound back, keeping any private material in place.
func reset() -> void:
	if not is_bound():
		return
	if _kind == _Kind.MATERIAL_EMISSION:
		(_slot.material as BaseMaterial3D).emission_enabled = _initial_emission_enabled
	write(initial)


## Puts the color and the material back as they were, then unbinds. Call [method bind] again to reuse it.
func restore() -> void:
	if not is_bound():
		return
	reset()
	if _slot != null:
		_slot.restore()
	_kind = _Kind.NONE
