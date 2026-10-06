@tool
@icon("res://addons/juice/icons/camera.svg")
class_name JuiceCameraShaker
extends JuiceCameraBase
## Shakes a [Camera2D] or [Camera3D] without touching its transform for good.
##
## It adds an offset on top of wherever the camera is, so a camera that follows the player
## keeps following. A [Camera2D] uses [member Camera2D.offset] and [member Node2D.rotation].
## A [Camera3D] uses [member Camera3D.h_offset] and [member Camera3D.v_offset] (the picture
## moves, the camera does not), or its local position when [member camera_3d_mode] says so.
##
## It knows two kinds of shake and handles both at the same time:
## [br]- A timed shake: noise of a set amplitude and frequency that fades out over the duration.
## [br]- Trauma: a value from 0 to 1 that every hit adds to and that drains over time. The
## strength of the shake is [code]trauma ^ trauma_exponent[/code], so small hits barely show
## and big ones pile up.
##
## Listens to [code]juice_camera_shake[/code]. Payload keys: [code]duration[/code],
## [code]amplitude[/code] (Vector2, pixels), [code]amplitude_3d[/code] (Vector3, units),
## [code]roll[/code] (degrees), [code]frequency[/code], [code]infinite[/code] (shakes until a
## stop event) and [code]trauma[/code] (when present the event adds that much trauma and nothing else).

const EVENT := &"juice_camera_shake"

## VIEW_OFFSET shifts the picture with h_offset and v_offset. TRANSFORM moves the camera
## itself, which also gives depth (z) shakes.
enum Camera3DMode { VIEW_OFFSET, TRANSFORM }

@export_group("Timed Shake")
## React to timed shakes.
@export var accept_timed_shakes: bool = true
## How a [Camera3D] is shaken.
@export var camera_3d_mode: Camera3DMode = Camera3DMode.VIEW_OFFSET
## The largest offset of a [Camera2D], in pixels, per axis.
@export var amplitude: Vector2 = Vector2(8.0, 8.0)
## The largest offset of a [Camera3D], in units, per axis.
@export var amplitude_3d: Vector3 = Vector3(0.1, 0.1, 0.0)
## The largest roll of the camera, in degrees.
@export_range(0.0, 45.0, 0.1, "or_greater", "suffix:deg") var roll: float = 0.0
## How fast the noise changes, in changes per second.
@export_range(0.0, 120.0, 0.1, "or_greater", "suffix:Hz") var frequency: float = 40.0
## Fades the shake out along [member attenuation]. Infinite shakes do not fade.
@export var use_attenuation: bool = true
## The strength over the whole shake. Empty fades out in a straight line.
@export var attenuation: Curve

@export_group("Trauma")
## React to trauma added by feedbacks.
@export var accept_trauma: bool = true
## How much trauma drains per second.
@export_range(0.0, 10.0, 0.01, "or_greater") var trauma_decay: float = 1.0
## The shake strength is trauma to this power. 2 or 3 feels good.
@export_range(1.0, 5.0, 0.1) var trauma_exponent: float = 2.0
## How fast the trauma noise changes, in changes per second.
@export_range(0.0, 120.0, 0.1, "or_greater", "suffix:Hz") var trauma_frequency: float = 30.0
## The largest offset of a [Camera2D] at full trauma, in pixels.
@export var max_offset: Vector2 = Vector2(32.0, 24.0)
## The largest offset of a [Camera3D] at full trauma, in units.
@export var max_offset_3d: Vector3 = Vector3(0.2, 0.2, 0.0)
## The largest roll at full trauma, in degrees.
@export_range(0.0, 45.0, 0.1, "or_greater", "suffix:deg") var max_roll: float = 4.0

## The current trauma, from 0 to 1.
var trauma: float = 0.0

var _noise: FastNoiseLite
var _p_amplitude: Vector3 = Vector3.ZERO
var _p_roll: float = 0.0
var _p_frequency: float = 0.0
var _p_attenuate: bool = true
var _p_curve: Curve
var _seed: float = 0.0
var _curve_offset: Vector3 = Vector3.ZERO
var _curve_roll: float = 0.0
var _trauma_time: float = 0.0


func _init() -> void:
	shake_duration = 0.3


## Adds [param amount] to the trauma, up to 1.
func add_trauma(amount: float) -> void:
	if not is_inside_tree():
		return
	trauma = clampf(trauma + amount, 0.0, 1.0)
	wake()


## Sets the trauma to [param value], from 0 to 1.
func set_trauma(value: float) -> void:
	trauma = clampf(value, 0.0, 1.0)
	wake()


# --- JuiceShaker -----------------------------------------------------------

func _get_events() -> Array[StringName]:
	return [EVENT]


func _receive(event: StringName, payload: Dictionary, reach: float) -> void:
	if payload.has("trauma"):
		if accept_trauma:
			add_trauma(float(payload["trauma"]) * reach)
		return
	if accept_timed_shakes:
		_begin(event, payload, reach)


func _on_begin(_event: StringName, payload: Dictionary, reach: float) -> bool:
	var node := get_target_node()
	if node is Camera3D:
		_p_amplitude = payload.get("amplitude_3d", amplitude_3d) * reach
	else:
		var flat: Vector2 = payload.get("amplitude", amplitude)
		_p_amplitude = Vector3(flat.x, flat.y, 0.0) * reach
	_p_roll = float(payload.get("roll", roll)) * reach
	_p_frequency = float(payload.get("frequency", frequency))
	_p_attenuate = use_attenuation
	_p_curve = attenuation
	if bool(payload.get("infinite", false)):
		_run_permanent = true
	_ensure_noise()
	_seed = randf_range(0.0, 100.0)
	return true


func _shake(progress: float, seconds: float) -> void:
	var fade := 1.0
	if _p_attenuate and not _run_permanent:
		fade = 1.0 - progress if _p_curve == null else _p_curve.sample(clampf(progress, 0.0, 1.0))
	var time := seconds * _p_frequency * 0.5 + _seed
	_curve_offset = Vector3(_n(time, 0), _n(time, 1), _n(time, 2)) * _p_amplitude * fade
	_curve_roll = _n(time, 3) * _p_roll * fade


func _tick(delta: float) -> void:
	var trauma_offset := Vector3.ZERO
	var trauma_roll := 0.0
	if trauma > 0.0:
		_ensure_noise()
		_trauma_time += delta
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		var power := pow(trauma, trauma_exponent)
		var time := _trauma_time * trauma_frequency * 0.5 + 1000.0
		var node := get_target_node()
		var reach_3d := node is Camera3D
		var limit: Vector3 = max_offset_3d if reach_3d else Vector3(max_offset.x, max_offset.y, 0.0)
		trauma_offset = Vector3(_n(time, 4), _n(time, 5), _n(time, 6)) * limit * power
		trauma_roll = _n(time, 7) * max_roll * power
	if not _shaking and trauma <= 0.0:
		_curve_offset = Vector3.ZERO
		_curve_roll = 0.0
		clear_all_offsets()
		return
	_apply(_curve_offset + trauma_offset, _curve_roll + trauma_roll)


func _is_busy() -> bool:
	return trauma > 0.0


func _on_restore() -> void:
	_curve_offset = Vector3.ZERO
	_curve_roll = 0.0


func _on_exit() -> void:
	trauma = 0.0
	_curve_offset = Vector3.ZERO
	_curve_roll = 0.0


## Ends the shake and drains the trauma at once.
func restore() -> void:
	trauma = 0.0
	super.restore()


func _apply(offset: Vector3, roll_degrees: float) -> void:
	var node := get_target_node()
	if node is Camera2D:
		set_offset(node, "offset", Vector2(offset.x, offset.y))
		set_offset(node, "rotation", deg_to_rad(roll_degrees))
	elif node is Camera3D:
		if camera_3d_mode == Camera3DMode.TRANSFORM:
			set_offset(node, "position", offset)
		else:
			set_offset(node, "h_offset", offset.x)
			set_offset(node, "v_offset", offset.y)
		set_offset(node, "rotation:z", deg_to_rad(roll_degrees))


func _ensure_noise() -> void:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.seed = randi()


# Smooth noise in -1..1. Each channel reads another row so the axes do not move together.
func _n(time: float, channel_index: int) -> float:
	return _noise.get_noise_2d(time, float(channel_index) * 17.3)
