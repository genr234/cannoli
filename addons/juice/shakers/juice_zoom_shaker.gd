@tool
@icon("res://addons/juice/icons/camera.svg")
class_name JuiceZoomShaker
extends JuiceCameraBase
## Zooms a [Camera2D] or [Camera3D], and animates the field of view or the size of a [Camera3D].
##
## Three events end up here:
## [br]- [code]juice_camera_zoom[/code] (from [JuiceCameraZoom]) zooms by a factor. A factor of 2
## shows half the area. A [Camera2D] changes its [member Camera2D.zoom], a perspective
## [Camera3D] its field of view (so it looks like a zoom) and an orthographic one its size.
## [br]- [code]juice_camera_fov[/code] (from [JuiceCameraFov]) plays a curve on the field of view.
## [br]- [code]juice_camera_ortho_size[/code] (from [JuiceCameraOrthoSize]) plays a curve on the size.
##
## Zoom payload keys: [code]mode[/code] (0 FOR, 1 SET, 2 RESET, see [enum ZoomMode]),
## [code]factor[/code], [code]transition_duration[/code], [code]hold[/code], [code]tween[/code]
## ([JuiceTween] or null), [code]amount[/code] (share of the effect).
## [br]Fov and size payload keys: [code]duration[/code], [code]curve[/code] ([Curve] or null for a bump),
## [code]remap_zero[/code], [code]remap_one[/code], [code]relative[/code], [code]amount[/code].
##
## The zoom is additive on the camera's own value, so it stacks with other shakers and
## with a follow script that moves the camera.

const EVENT_ZOOM := &"juice_camera_zoom"
const EVENT_FOV := &"juice_camera_fov"
const EVENT_ORTHO_SIZE := &"juice_camera_ortho_size"

## FOR zooms in, holds, and comes back. SET zooms and stays. RESET goes back to the normal view.
enum ZoomMode { FOR, SET, RESET }

@export_group("Zoom")
## What the zoom does.
@export var zoom_mode: ZoomMode = ZoomMode.FOR
## How much to zoom in. 2 shows half the area, 0.5 shows twice the area.
@export_range(0.05, 10.0, 0.01, "or_greater") var zoom_factor: float = 1.5
## Seconds to get to the zoom. 0 jumps at once.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var transition_duration: float = 0.1
## Seconds to stay zoomed in. Only FOR holds.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var hold_duration: float = 0.1
## The easing of the transitions. Empty is linear.
@export var tween: JuiceTween

@export_group("Field of View and Size")
## The curve over the shake. Empty is a bump that rises and falls.
@export var curve: Curve
## The field of view at curve value 0, in degrees.
@export_range(1.0, 179.0, 0.1, "suffix:deg") var fov_zero: float = 60.0
## The field of view at curve value 1, in degrees.
@export_range(1.0, 179.0, 0.1, "suffix:deg") var fov_one: float = 90.0
## The size at curve value 0.
@export var size_zero: float = 5.0
## The size at curve value 1.
@export var size_one: float = 7.0
## Adds the remapped value to the camera's own value instead of replacing it.
@export var relative: bool = false

var _kind: StringName = EVENT_ZOOM
var _factor: float = 1.0
var _mode: ZoomMode = ZoomMode.FOR
var _from: float = 1.0
var _to: float = 1.0
var _in: float = 0.0
var _hold: float = 0.0
var _tween: JuiceTween
var _property: String = ""
var _start: float = 0.0
var _curve: Curve
var _zero: float = 0.0
var _one: float = 0.0
var _relative: bool = false
var _amount: float = 1.0


func _init() -> void:
	shake_duration = 0.3


## The zoom factor the shaker is at right now, 1 when it is not zoomed.
func get_factor() -> float:
	return _factor


# --- JuiceShaker -----------------------------------------------------------

func _get_events() -> Array[StringName]:
	return [EVENT_ZOOM, EVENT_FOV, EVENT_ORTHO_SIZE]


func _on_begin(event: StringName, payload: Dictionary, reach: float) -> bool:
	var node := get_target_node()
	_kind = event
	_run_permanent = false
	_amount = float(payload.get("amount", 1.0)) * reach
	if event == EVENT_ZOOM:
		return _begin_zoom(payload)
	if not node is Camera3D:
		return false
	var perspective := (node as Camera3D).projection == Camera3D.PROJECTION_PERSPECTIVE
	if event == EVENT_FOV:
		if not perspective:
			return false
		_property = "fov"
		_zero = float(payload.get("remap_zero", fov_zero))
		_one = float(payload.get("remap_one", fov_one))
	else:
		if perspective:
			return false
		_property = "size"
		_zero = float(payload.get("remap_zero", size_zero))
		_one = float(payload.get("remap_one", size_one))
	_curve = payload.get("curve", curve)
	_relative = bool(payload.get("relative", relative))
	_start = float(get_base_value(node, _property))
	return true


func _begin_zoom(payload: Dictionary) -> bool:
	_mode = int(payload.get("mode", zoom_mode)) as ZoomMode
	var wanted := float(payload.get("factor", zoom_factor))
	_in = float(payload.get("transition_duration", transition_duration))
	_hold = float(payload.get("hold", hold_duration))
	_tween = payload.get("tween", tween)
	_from = _factor
	if _mode == ZoomMode.RESET:
		_to = 1.0
	else:
		_to = maxf(0.01, 1.0 + (wanted - 1.0) * _amount)
	_duration = _in
	if _mode == ZoomMode.FOR:
		_duration = _in * 2.0 + _hold
	# A zoom that was set stays until something resets it.
	_reset_target = _mode != ZoomMode.SET
	return true


func _shake(progress: float, _seconds: float) -> void:
	var node := get_target_node()
	if node == null:
		return
	if _kind == EVENT_ZOOM:
		_factor = _zoom_at(_journey)
		_apply_factor(node, _factor)
		return
	var value := sample_remap(_curve, progress, _zero, _one)
	var offset := value * _amount if _relative else (value - _start) * _amount
	set_offset(node, _property, offset)


func _zoom_at(time: float) -> float:
	if time < _in:
		return lerpf(_from, _to, JuiceTween.sample(_tween, time / _in))
	if _mode != ZoomMode.FOR:
		return _to
	var hold_end := _in + _hold
	if time <= hold_end:
		return _to
	if _in <= 0.0:
		return 1.0
	return lerpf(_to, 1.0, JuiceTween.sample(_tween, clampf((time - hold_end) / _in, 0.0, 1.0)))


func _apply_factor(node: Node, factor: float) -> void:
	if node is Camera2D:
		var base: Vector2 = get_base_value(node, "zoom")
		set_offset(node, "zoom", base * factor - base)
	elif node is Camera3D:
		if (node as Camera3D).projection == Camera3D.PROJECTION_PERSPECTIVE:
			var base_fov: float = get_base_value(node, "fov")
			var fov := rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) * 0.5) / factor))
			set_offset(node, "fov", clampf(fov, 1.0, 179.0) - base_fov)
		else:
			var base_size: float = get_base_value(node, "size")
			set_offset(node, "size", base_size / factor - base_size)


func _on_restore() -> void:
	_factor = 1.0
