@tool
@icon("res://addons/juice/icons/shaker.svg")
@abstract
class_name JuiceNodeShake
extends JuiceFeedback
## The shared part of [JuicePositionShake], [JuiceRotationShake] and [JuiceScaleShake].
##
## These feedbacks broadcast the shake settings to the matching shakers
## ([JuicePositionShaker], [JuiceRotationShaker], [JuiceScaleShaker]) on the channel, so a node
## can be shaken from anywhere without a reference to it, and many nodes can shake at once.
## The settings have the same names as on [JuiceTransformShaker].
##
## Intensity scales the amplitude.

@export_group("Shake")
## The kind of movement. See [enum JuiceTransformShaker.Wave].
@export var wave: JuiceTransformShaker.Wave = JuiceTransformShaker.Wave.SINE
## Seconds the shake lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## The largest offset, in the unit of the property (pixels, units, degrees or scale).
@export var amplitude: float = 8.0
## How many swings or changes per second.
@export_range(0.0, 120.0, 0.1, "or_greater", "suffix:Hz") var frequency: float = 8.0
## The axes that move and how much each one moves.
@export var direction: Vector3 = Vector3(1.0, 1.0, 0.0)
## Picks a random direction between [member direction] and [member alt_direction].
@export var random_direction: bool = false
## The other end of the random direction.
@export var alt_direction: Vector3 = Vector3(-1.0, -1.0, 0.0)
## Bends the SINE direction with noise.
@export var directional_noise: float = 0.25
## Scales the SINE direction to length 1.
@export var normalize_direction: bool = true
## The curve of the CURVE wave. Empty is a bump that rises and falls.
@export var value_curve: Curve
## Fades the shake in and out along [member attenuation].
@export var use_attenuation: bool = true
## The strength over the shake. Empty is a bump that rises and falls.
@export var attenuation: Curve
## Starts every shake at another point of the swing.
@export var randomize_seed: bool = true


## The bus event this feedback sends.
@abstract func _get_event() -> StringName


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_SHAKE


func _has_channel() -> bool:
	return true


func _has_range() -> bool:
	return true


func _has_randomness() -> bool:
	return true


func _on_play(feedback_intensity: float) -> void:
	broadcast(_get_event(), {
		"wave": wave,
		"duration": get_feedback_duration(),
		"amplitude": amplitude * feedback_intensity,
		"frequency": frequency,
		"direction": direction,
		"random_direction": random_direction,
		"alt_direction": alt_direction,
		"directional_noise": directional_noise,
		"normalize_direction": normalize_direction,
		"value_curve": value_curve,
		"use_attenuation": use_attenuation,
		"attenuation": attenuation,
		"randomize_seed": randomize_seed,
	})


func _on_stop() -> void:
	broadcast(_get_event(), {"stop": true})


func _on_restore() -> void:
	broadcast(_get_event(), {"restore": true})
