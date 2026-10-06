@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceLight
extends JuiceFeedback
## Animates a light: energy, color, range and shadows.
##
## Works on [Light2D] (energy, color, texture scale, shadow) and [Light3D] (energy, color,
## range of omni and spot lights, shadow). INSTANT sets the end values at once and
## optionally returns after a hold time. OVER_TIME blends from the start to the end values.
## It counts as a flash, so the accessibility flash multiplier and flash rate cap apply.

## How the change plays.
enum Style {
	## Applies the end values at once, then returns after [member duration].
	INSTANT,
	## Blends over [member duration].
	OVER_TIME,
}
## ABSOLUTE uses the values as they are. ADDITIVE adds them to what the light had.
enum Mode { ABSOLUTE, ADDITIVE }
## What to do with the shadow.
enum Shadow { UNCHANGED, ENABLE, DISABLE }

@export_group("Light")
## How the change plays.
@export var style: Style = Style.OVER_TIME
## How the values are used.
@export var mode: Mode = Mode.ABSOLUTE
## Seconds one play takes. For INSTANT, how long the change is held before it returns (0 keeps it).
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
## The curve of the blend. Null is a straight line.
@export var tween: JuiceTween
## Skips the change when the project's flash rate cap is reached.
@export var respect_flash_cap: bool = true
@export_group("Energy")
## Changes the energy.
@export var animate_energy: bool = true
## The energy at curve position 0.
@export var from_energy: float = 0.0
## The energy at curve position 1.
@export var to_energy: float = 2.0
@export_group("Color")
## Changes the color.
@export var animate_color: bool = false
## The color at curve position 0.
@export var from_color: Color = Color.WHITE
## The color at curve position 1.
@export var to_color: Color = Color.RED
@export_group("Range")
## Changes the reach: omni and spot range in 3D, texture scale in 2D.
@export var animate_range: bool = false
## The range at curve position 0.
@export var from_range: float = 1.0
## The range at curve position 1.
@export var to_range: float = 5.0
@export_group("Shadow")
## What to do with the shadow while the feedback runs.
@export var shadow: Shadow = Shadow.UNCHANGED

var _initial: Dictionary = {}
var _origin: Dictionary = {}
var _suppressed := false


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_FLASH


func _on_initialize() -> void:
	var node := get_target()
	if _is_supported(node):
		_initial = _read(node)
		_origin = _initial.duplicate()


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	if not is_retrigger():
		_origin = _read(node)
		_suppressed = respect_flash_cap and not Juice.try_flash()
	if _suppressed:
		return
	if shadow != Shadow.UNCHANGED:
		_set_shadow(node, shadow == Shadow.ENABLE)
	if style == Style.INSTANT or duration <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	if style == Style.INSTANT:
		return
	var node := get_target()
	if _is_supported(node) and not _suppressed:
		_apply(node, progress)


func _on_finished() -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	if style == Style.INSTANT and duration > 0.0:
		_write(node, _origin)
	if shadow != Shadow.UNCHANGED and not _origin.is_empty():
		_set_shadow(node, _origin["shadow"])


func _on_restore() -> void:
	var node := get_target()
	if _is_supported(node) and not _initial.is_empty():
		_write(node, _initial)
		_set_shadow(node, _initial["shadow"])


func _apply(node: Node, progress: float) -> void:
	var shaped := JuiceTween.sample(tween, progress)
	var intensity := get_intensity()
	var values := _origin.duplicate()
	if animate_energy:
		values["energy"] = _blend(_origin["energy"], from_energy, to_energy, shaped, intensity)
	if animate_color:
		values["color"] = _blend(_origin["color"], from_color, to_color, shaped, intensity)
	if animate_range and _origin.has("range"):
		values["range"] = _blend(_origin["range"], from_range, to_range, shaped, intensity)
	_write(node, values)


func _blend(origin: Variant, from_v: Variant, to_v: Variant, shaped: float, intensity: float) -> Variant:
	var between: Variant = Juice.mix(from_v, to_v, shaped)
	if mode == Mode.ADDITIVE:
		return Juice.add_values(origin, Juice.scale_value(between, intensity))
	return Juice.mix(origin, between, intensity)


func _is_supported(node: Node) -> bool:
	return node is Light2D or node is Light3D


func _read(node: Node) -> Dictionary:
	var values: Dictionary = {}
	if node is Light2D:
		var light_2d := node as Light2D
		values = {"energy": light_2d.energy, "color": light_2d.color, "shadow": light_2d.shadow_enabled}
		if light_2d is PointLight2D:
			values["range"] = (light_2d as PointLight2D).texture_scale
	else:
		var light_3d := node as Light3D
		values = {"energy": light_3d.light_energy, "color": light_3d.light_color, "shadow": light_3d.shadow_enabled}
		if light_3d is OmniLight3D:
			values["range"] = (light_3d as OmniLight3D).omni_range
		elif light_3d is SpotLight3D:
			values["range"] = (light_3d as SpotLight3D).spot_range
	return values


func _write(node: Node, values: Dictionary) -> void:
	if node is Light2D:
		var light_2d := node as Light2D
		light_2d.energy = maxf(values["energy"], 0.0)
		light_2d.color = values["color"]
		if values.has("range") and light_2d is PointLight2D:
			(light_2d as PointLight2D).texture_scale = maxf(values["range"], 0.01)
	elif node is Light3D:
		var light_3d := node as Light3D
		light_3d.light_energy = maxf(values["energy"], 0.0)
		light_3d.light_color = values["color"]
		if values.has("range"):
			if light_3d is OmniLight3D:
				(light_3d as OmniLight3D).omni_range = maxf(values["range"], 0.001)
			elif light_3d is SpotLight3D:
				(light_3d as SpotLight3D).spot_range = maxf(values["range"], 0.001)


func _set_shadow(node: Node, enabled: bool) -> void:
	if node is Light2D:
		(node as Light2D).shadow_enabled = enabled
	elif node is Light3D:
		(node as Light3D).shadow_enabled = enabled
