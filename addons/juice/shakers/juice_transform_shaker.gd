@tool
@icon("res://addons/juice/icons/shaker.svg")
@abstract
class_name JuiceTransformShaker
extends JuiceShaker
## The shared part of [JuicePositionShaker], [JuiceRotationShaker] and [JuiceScaleShaker].
##
## It computes a Vector3 offset over the shake and adds it to the target. A subclass only
## says which property to add it to. The offset is zero at the start and the end of the
## shake when attenuation is on, and it is removed again when the shake is over.
##
## The values below can come from the feedback that sends the event. Its payload keys have
## the same names as these properties: [code]wave, amplitude, frequency, direction,
## random_direction, alt_direction, directional_noise, normalize_direction, value_curve,
## use_attenuation, attenuation, randomize_seed[/code].

## How the offset moves. SINE swings back and forth along the direction. NOISE moves each
## axis on smooth noise. RANDOM jumps to a new random value each period. CURVE follows
## [member value_curve] along the direction.
enum Wave { SINE, NOISE, RANDOM, CURVE }

@export_group("Shake")
## The kind of movement.
@export var wave: Wave = Wave.SINE
## The largest offset, in the unit of the property (pixels, units, degrees or scale).
@export var amplitude: float = 8.0
## How many swings or changes per second.
@export_range(0.0, 120.0, 0.1, "or_greater", "suffix:Hz") var frequency: float = 8.0
## The axes that move and how much each one moves. Rotation uses z for 2D nodes.
@export var direction: Vector3 = Vector3(1.0, 1.0, 0.0)
## Picks a random direction between [member direction] and [member alt_direction] for every shake.
@export var random_direction: bool = false
## The other end of the random direction.
@export var alt_direction: Vector3 = Vector3(-1.0, -1.0, 0.0)
## Bends the SINE direction with noise, so the swing is not a straight line.
@export var directional_noise: float = 0.25
## Scales the SINE direction to length 1, so the amplitude is the largest offset on the line.
@export var normalize_direction: bool = true
## The curve of the CURVE wave over the whole shake. Empty is a bump that rises and falls.
@export var value_curve: Curve
## Fades the shake in and out along [member attenuation]. Ignored for permanent shakes.
@export var use_attenuation: bool = true
## The strength over the whole shake. Empty is a bump that rises and falls.
@export var attenuation: Curve
## Starts every shake at another point of the swing, so shakers do not move in step.
@export var randomize_seed: bool = true

var _noise: FastNoiseLite
var _p_wave: Wave = Wave.SINE
var _p_amplitude: float = 0.0
var _p_frequency: float = 0.0
var _p_direction: Vector3 = Vector3.ZERO
var _p_directional_noise: float = 0.0
var _p_normalize: bool = true
var _p_curve: Curve
var _p_use_attenuation: bool = true
var _p_attenuation: Curve
var _seed: float = 0.0
var _next_random: float = 0.0
var _random_value: Vector3 = Vector3.ZERO


# --- Subclass hooks --------------------------------------------------------

## The property to offset on [param node], or an empty string for an unsupported node.
func _get_property(_node: Node) -> String:
	return ""


## Turns the Vector3 offset into a value of the property of [param node].
func _convert(_node: Node, offset: Vector3) -> Variant:
	return offset


# --- JuiceShaker -----------------------------------------------------------

func _is_target_supported(node: Node) -> bool:
	return not _get_property(node).is_empty()


func _on_begin(_event: StringName, payload: Dictionary, reach: float) -> bool:
	_p_wave = int(payload.get("wave", wave)) as Wave
	_p_amplitude = float(payload.get("amplitude", amplitude)) * reach
	_p_frequency = float(payload.get("frequency", frequency))
	var main: Vector3 = payload.get("direction", direction)
	if bool(payload.get("random_direction", random_direction)):
		var alt: Vector3 = payload.get("alt_direction", alt_direction)
		main = Vector3(randf_range(main.x, alt.x), randf_range(main.y, alt.y), randf_range(main.z, alt.z))
	_p_direction = main
	_p_directional_noise = float(payload.get("directional_noise", directional_noise))
	_p_normalize = bool(payload.get("normalize_direction", normalize_direction))
	_p_curve = payload.get("value_curve", value_curve)
	_p_use_attenuation = bool(payload.get("use_attenuation", use_attenuation))
	_p_attenuation = payload.get("attenuation", attenuation)
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
	if bool(payload.get("randomize_seed", randomize_seed)):
		_seed = randf_range(0.0, 100.0)
		_noise.seed = randi()
	_next_random = 0.0
	return true


func _shake(progress: float, seconds: float) -> void:
	var node := get_target_node()
	if node == null:
		return
	var property := _get_property(node)
	if property.is_empty():
		return
	var strength := _p_amplitude
	if _p_use_attenuation and not _run_permanent:
		strength *= sample_bump(_p_attenuation, progress)
	var offset := Vector3.ZERO
	match _p_wave:
		Wave.SINE:
			var swing := _p_direction
			if _p_directional_noise != 0.0:
				swing += Vector3(_axis_noise(seconds, 0), _axis_noise(seconds, 1), _axis_noise(seconds, 2)) * _p_directional_noise
			if _p_normalize:
				swing = swing.normalized()
			offset = swing * sin(TAU * _p_frequency * (seconds + _seed)) * strength
		Wave.NOISE:
			var smooth := Vector3(_axis_noise(seconds, 0), _axis_noise(seconds, 1), _axis_noise(seconds, 2))
			offset = smooth * _p_direction * strength
		Wave.RANDOM:
			if seconds >= _next_random:
				_random_value = Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
				_next_random = seconds + (1.0 / _p_frequency if _p_frequency > 0.0 else INF)
			offset = _random_value * _p_direction * strength
		Wave.CURVE:
			offset = _p_direction * sample_bump(_p_curve, progress) * strength
	set_offset(node, property, _convert(node, offset))


# One smooth value in -1..1 per axis. The axes read far apart places of the noise.
func _axis_noise(seconds: float, axis: int) -> float:
	return _noise.get_noise_2d(seconds * _p_frequency * 0.5 + _seed, float(axis) * 31.7)
