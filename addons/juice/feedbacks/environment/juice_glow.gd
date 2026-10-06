@tool
@icon("res://addons/juice/icons/environment.svg")
class_name JuiceGlow
extends JuiceEnvironmentBase
## Animates the glow (bloom) of the world [Environment], such as a blinding bloom on an explosion.
##
## Pick one glow value and the range to blend it over. Chain several of these to animate
## more than one value. Glow is switched on when the feedback plays.

## The glow value to animate.
enum Value {
	## How strong the glow is overall.
	INTENSITY,
	## How far the glow spreads.
	STRENGTH,
	## How much of the whole image blooms, not just bright parts.
	BLOOM,
	## The brightness a pixel needs before it glows.
	HDR_THRESHOLD,
	## How much glow bright pixels add.
	HDR_SCALE,
	## The most brightness that can glow.
	HDR_LUMINANCE_CAP,
}

const _NAMES := {
	Value.INTENSITY: &"glow_intensity",
	Value.STRENGTH: &"glow_strength",
	Value.BLOOM: &"glow_bloom",
	Value.HDR_THRESHOLD: &"glow_hdr_threshold",
	Value.HDR_SCALE: &"glow_hdr_scale",
	Value.HDR_LUMINANCE_CAP: &"glow_hdr_luminance_cap",
}

@export_group("Glow")
## Which glow value to animate.
@export var value: Value = Value.INTENSITY
## The value at curve position 0.
@export var from_value: float = 0.8
## The value at curve position 1.
@export var to_value: float = 2.0
## Turns glow on in the environment when the feedback plays.
@export var enable_glow: bool = true


func _get_category() -> StringName:
	return Juice.CATEGORY_FLASH


func _get_changes() -> Array[Dictionary]:
	return [{"holder": _ENVIRONMENT, "property": _NAMES[value], "from": from_value, "to": to_value}]


func _get_switches() -> Array[Dictionary]:
	if enable_glow:
		return [{"holder": _ENVIRONMENT, "property": &"glow_enabled", "value": true}]
	return []
