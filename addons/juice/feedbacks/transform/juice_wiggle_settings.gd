@tool
class_name JuiceWiggleSettings
extends Resource
## The look of one wiggle: how it moves, how big it is and how fast.
##
## [JuiceWiggle] holds one of these for position, one for rotation and one for scale.
## The settings are only read, never changed while playing, so a resource can be shared.

## RANDOM moves to a new random value every step. PING_PONG alternates between the
## minimum and maximum amplitude. NOISE follows smooth Perlin noise. CURVE plays
## [member curve] over and over.
enum Type { RANDOM, PING_PONG, NOISE, CURVE }

@export_group("Wiggle")
## The kind of movement.
@export var type: Type = Type.RANDOM:
	set(value):
		type = value
		notify_property_list_changed()
## A multiplier on the time of this wiggle. Above 1 is faster.
@export_range(0.0, 10.0, 0.01, "or_greater") var time_multiplier: float = 1.0
## Multiplies the amplitude over the length of the wiggle (0 at the start, 1 at the end).
## Null fades the wiggle out in a straight line.
@export var falloff: Curve

@export_group("Steps")
## The shortest time in seconds between two changes (RANDOM, PING_PONG, CURVE).
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var frequency_min: float = 0.05
## The longest time in seconds between two changes (RANDOM, PING_PONG, CURVE).
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var frequency_max: float = 0.1
## The shortest rest in seconds between two steps (RANDOM, PING_PONG, CURVE).
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var pause_min: float = 0.0
## The longest rest in seconds between two steps (RANDOM, PING_PONG, CURVE).
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var pause_max: float = 0.0
## The easing of a step (RANDOM, PING_PONG). Null is a straight line.
@export var step_tween: JuiceTween

@export_group("Amplitude")
## The lowest value, or the first end of a PING_PONG.
@export var amplitude_min: Vector3 = Vector3(-10.0, -10.0, -10.0)
## The highest value, or the second end of a PING_PONG.
@export var amplitude_max: Vector3 = Vector3(10.0, 10.0, 10.0)
## True adds the wiggle to the value the node had. False uses the amplitude as the value.
@export var relative: bool = true
## Uses the x value for all axes.
@export var uniform_values: bool = false
## Forces the length of a random amplitude (RANDOM and NOISE).
@export var force_vector_length: bool = false
## The length used when [member force_vector_length] is on.
@export var forced_vector_length: float = 1.0

@export_group("Noise")
## The lowest speed of the noise on each axis.
@export var noise_frequency_min: Vector3 = Vector3.ZERO
## The highest speed of the noise on each axis.
@export var noise_frequency_max: Vector3 = Vector3.ONE
## The lowest offset in the noise on each axis. Different offsets make axes independent.
@export var noise_shift_min: Vector3 = Vector3.ZERO
## The highest offset in the noise on each axis.
@export var noise_shift_max: Vector3 = Vector3.ZERO

@export_group("Curve")
## The shape of one step. Null is a straight line.
@export var curve_tween: JuiceTween
## The lowest value a curve value of 0 maps to.
@export var remap_zero_min: Vector3 = Vector3.ZERO
## The highest value a curve value of 0 maps to.
@export var remap_zero_max: Vector3 = Vector3.ZERO
## The lowest value a curve value of 1 maps to.
@export var remap_one_min: Vector3 = Vector3.ONE
## The highest value a curve value of 1 maps to.
@export var remap_one_max: Vector3 = Vector3.ONE
## Plays the curve forward, then backward, instead of always forward.
@export var curve_ping_pong: bool = false


func _validate_property(property: Dictionary) -> void:
	var prop_name: String = property.name
	var hidden := false
	match prop_name:
		"Noise", "noise_frequency_min", "noise_frequency_max", "noise_shift_min", "noise_shift_max":
			hidden = type != Type.NOISE
		"Curve", "curve_tween", "remap_zero_min", "remap_zero_max", "remap_one_min", "remap_one_max", "curve_ping_pong":
			hidden = type != Type.CURVE
		"Steps", "frequency_min", "frequency_max", "pause_min", "pause_max":
			hidden = type == Type.NOISE
		"step_tween":
			hidden = type == Type.NOISE or type == Type.CURVE
		"force_vector_length", "forced_vector_length":
			hidden = type == Type.PING_PONG or type == Type.CURVE
	if not hidden:
		return
	if property.usage & PROPERTY_USAGE_GROUP:
		property.usage = PROPERTY_USAGE_NONE
	else:
		property.usage &= ~PROPERTY_USAGE_EDITOR


## A preset for moving a node: a quick shake of about 10 pixels or units.
static func make_position() -> JuiceWiggleSettings:
	return JuiceWiggleSettings.new()


## A preset for rotating a node: a few degrees of noise.
static func make_rotation() -> JuiceWiggleSettings:
	var settings := JuiceWiggleSettings.new()
	settings.amplitude_min = Vector3(-5.0, -5.0, -5.0)
	settings.amplitude_max = Vector3(5.0, 5.0, 5.0)
	return settings


## A preset for scaling a node: a small pulse around its scale.
static func make_scale() -> JuiceWiggleSettings:
	var settings := JuiceWiggleSettings.new()
	settings.amplitude_min = Vector3(-0.1, -0.1, -0.1)
	settings.amplitude_max = Vector3(0.1, 0.1, 0.1)
	return settings
