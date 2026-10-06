@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceBlink
extends JuiceFeedback
## Blinks a node on and off in timed phases, such as an invulnerability blink that gets faster.
##
## The first phase uses [member on_duration], [member off_duration] and [member cycles]. More
## phases can follow in [member extra_phases]. The node returns to normal when the
## blink ends. It counts as a flash, so the accessibility flash multiplier and flash rate cap
## apply to it.

## What the off state does to the node.
enum Method {
	## Hides the node (visible = false).
	VISIBILITY,
	## Fades the alpha of its color to [member off_alpha].
	ALPHA,
	## Changes its color to [member off_color].
	COLOR,
	## Turns the emission of its 3D material to [member off_color].
	EMISSION,
}

@export_group("Blink")
## What changes between the on and off state.
@export var method: Method = Method.VISIBILITY:
	set(value):
		method = value
		notify_property_list_changed()
## Seconds of the on state in each cycle of the first phase.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var on_duration: float = 0.1
## Seconds of the off state in each cycle of the first phase.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var off_duration: float = 0.1
## Cycles of the first phase.
@export_range(1, 100, 1, "or_greater") var cycles: int = 4
## Phases played after the first one.
@export var extra_phases: Array[JuiceBlinkPhase] = []
## Starts with the off state instead of the on state.
@export var start_off: bool = false
## The alpha in the off state for ALPHA.
@export_range(0.0, 1.0, 0.01) var off_alpha: float = 0.2
## The color in the off state for COLOR and EMISSION.
@export var off_color: Color = Color(0.0, 0.0, 0.0, 1.0)
## Skips the blink when the project's flash rate cap is reached.
@export var respect_flash_cap: bool = true
@export_group("Material")
## The shader uniform to blink on 3D and shader-material targets. Empty uses the natural color.
@export var parameter: StringName = &""
## Treats [member parameter] as an instance uniform of a 3D node.
@export var use_instance_parameter: bool = false
## Edits a private copy of the material, so other nodes sharing it do not blink too.
@export var duplicate_material: bool = true

var _channel: JuiceColorChannel
var _bound_node: Node
var _initial_visible := true
var _suppressed := false


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "off_alpha" and method != Method.ALPHA:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "off_color" and method != Method.COLOR and method != Method.EMISSION:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["parameter", "use_instance_parameter", "duplicate_material"] and method == Method.VISIBILITY:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	var total := (on_duration + off_duration) * cycles
	for phase in extra_phases:
		if phase != null:
			total += phase.get_duration()
	return total


func _get_category() -> StringName:
	return Juice.CATEGORY_FLASH


func _on_initialize() -> void:
	_bind()


func _on_play(_feedback_intensity: float) -> void:
	_bind()
	if not is_retrigger():
		_suppressed = respect_flash_cap and not Juice.try_flash()
		var node := get_target()
		if node != null and "visible" in node:
			_initial_visible = node.visible


func _on_progress(progress: float) -> void:
	if _suppressed:
		return
	var total := _get_duration()
	if total <= 0.0:
		return
	var time := clampf(progress, 0.0, 1.0) * total
	if progress >= 1.0 or progress <= 0.0:
		_restore_node()
		return
	_apply(_is_on(time))


func _on_finished() -> void:
	_restore_node()


func _on_restore() -> void:
	_restore_node()
	if _channel != null:
		_channel.restore()


# Walks the phases to find whether [param time] falls in an on or off stretch.
func _is_on(time: float) -> bool:
	var left := time
	var phases: Array[Vector3] = [Vector3(on_duration, off_duration, cycles)]
	for phase in extra_phases:
		if phase != null:
			phases.append(Vector3(phase.on_duration, phase.off_duration, phase.cycles))
	for phase_values in phases:
		var length := (phase_values.x + phase_values.y) * phase_values.z
		if left < length or phase_values == phases[phases.size() - 1]:
			var in_cycle := fposmod(left, maxf(phase_values.x + phase_values.y, 0.0001))
			var on_first := in_cycle < phase_values.x
			return on_first != start_off
		left -= length
	return true


func _apply(on: bool) -> void:
	var node := get_target()
	if node == null:
		return
	var weight := clampf(get_intensity(), 0.0, 1.0)
	match method:
		Method.VISIBILITY:
			if "visible" in node:
				node.visible = true if on or weight <= 0.0 else false
		Method.ALPHA:
			if _channel != null and _channel.is_bound():
				var base := _channel.initial
				_channel.write(base if on else Color(base.r, base.g, base.b, lerpf(base.a, off_alpha * base.a, weight)))
		Method.COLOR, Method.EMISSION:
			if _channel != null and _channel.is_bound():
				_channel.write(_channel.initial if on else _channel.initial.lerp(off_color, weight))


func _restore_node() -> void:
	var node := get_target()
	if method == Method.VISIBILITY:
		if node != null and "visible" in node:
			node.visible = _initial_visible
	elif _channel != null:
		_channel.reset()


func _bind() -> void:
	var node := get_target()
	if node == _bound_node and (method == Method.VISIBILITY or (_channel != null and _channel.is_bound())):
		return
	if _channel != null:
		_channel.restore()
	_bound_node = node
	_channel = null
	if node == null:
		return
	if "visible" in node:
		_initial_visible = node.visible
	if method != Method.VISIBILITY:
		_channel = JuiceColorChannel.new()
		_channel.bind(node, parameter, use_instance_parameter, false, method == Method.EMISSION, duplicate_material)
