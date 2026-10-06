@tool
class_name JuiceScreenEffects
extends CanvasLayer
## Draws screen effects (zoom punch, lens distortion, chromatic aberration, vignette)
## with one shader over the whole viewport.
##
## There is one of these per viewport. [method get_for] finds it or creates it. Each
## effect value is the sum of the contributions of different owners, so two
## feedbacks that both add vignette do not overwrite each other. The layer
## hides itself while every contribution is neutral.

## The shader parameters that can be driven with [method set_contribution].
const PARAM_ZOOM := &"zoom"
const PARAM_LENS := &"lens_distortion"
const PARAM_CHROMATIC := &"chromatic_aberration"
const PARAM_VIGNETTE := &"vignette_intensity"

const _NODE_NAME := "JuiceScreenEffects"
const _SHADER := preload("res://addons/juice/effects/juice_screen_effects.gdshader")

var _rect: ColorRect
var _material: ShaderMaterial
# param -> { owner key -> value }
var _contributions: Dictionary[StringName, Dictionary] = {}


## Returns the effects layer for the viewport of [param context], creating it when needed.
## Returns null when the context is not in a tree.
static func get_for(context: Node, overlay_layer: int = 90) -> JuiceScreenEffects:
	if context == null or not context.is_inside_tree():
		return null
	var viewport := context.get_viewport()
	if viewport == null:
		return null
	var existing := viewport.get_node_or_null(_NODE_NAME)
	if existing is JuiceScreenEffects:
		return existing
	var effects := JuiceScreenEffects.new()
	effects.name = _NODE_NAME
	effects.layer = overlay_layer
	viewport.add_child(effects)
	return effects


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material = ShaderMaterial.new()
	_material.shader = _SHADER
	_rect = ColorRect.new()
	_rect.name = "Rect"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.material = _material
	add_child(_rect)
	visible = false


## Sets what [param owner_key] adds to [param param]. Use a unique int such as the
## instance id of the caller.
func set_contribution(param: StringName, owner_key: int, value: float) -> void:
	if not _contributions.has(param):
		_contributions[param] = {}
	_contributions[param][owner_key] = value
	_push(param)


## Removes everything [param owner_key] added.
func clear_contributions(owner_key: int) -> void:
	for param: StringName in _contributions.keys():
		var entries: Dictionary = _contributions[param]
		if entries.erase(owner_key):
			_push(param)


## Sets a shader parameter that is not summed, such as [code]vignette_color[/code].
func set_value(param: StringName, value: Variant) -> void:
	_material.set_shader_parameter(param, value)


## The summed value of a parameter.
func get_total(param: StringName) -> float:
	var total := 0.0
	var entries: Dictionary = _contributions.get(param, {})
	for value: float in entries.values():
		total += value
	return total


func _push(param: StringName) -> void:
	_material.set_shader_parameter(param, get_total(param))
	var active := false
	for key: StringName in _contributions:
		if not is_zero_approx(get_total(key)):
			active = true
			break
	visible = active
