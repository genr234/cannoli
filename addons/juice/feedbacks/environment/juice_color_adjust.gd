@tool
@icon("res://addons/juice/icons/environment.svg")
class_name JuiceColorAdjust
extends JuiceEnvironmentBase
## Animates the color adjustment and tonemapping of the world [Environment], such as a
## desaturated hurt look or a bright flash of exposure.
##
## Pick one value and the range to blend it over. Chain several of these to animate more
## than one value. The adjustment is switched on when the feedback plays.

## The value to animate.
enum Value {
	## Overall brightness. 1 is normal.
	BRIGHTNESS,
	## Contrast. 1 is normal.
	CONTRAST,
	## Saturation. 1 is normal, 0 is black and white.
	SATURATION,
	## The exposure of the tonemapper. 1 is normal.
	TONEMAP_EXPOSURE,
	## The white point of the tonemapper.
	TONEMAP_WHITE,
}

const _NAMES := {
	Value.BRIGHTNESS: &"adjustment_brightness",
	Value.CONTRAST: &"adjustment_contrast",
	Value.SATURATION: &"adjustment_saturation",
	Value.TONEMAP_EXPOSURE: &"tonemap_exposure",
	Value.TONEMAP_WHITE: &"tonemap_white",
}

@export_group("Color Adjust")
## Which value to animate.
@export var value: Value = Value.SATURATION
## The value at curve position 0.
@export var from_value: float = 1.0
## The value at curve position 1.
@export var to_value: float = 0.0
## Turns the adjustment on in the environment when the feedback plays. Only used by the
## brightness, contrast and saturation values.
@export var enable_adjustment: bool = true


func _get_changes() -> Array[Dictionary]:
	return [{"holder": _ENVIRONMENT, "property": _NAMES[value], "from": from_value, "to": to_value}]


func _get_switches() -> Array[Dictionary]:
	if enable_adjustment and value <= Value.SATURATION:
		return [{"holder": _ENVIRONMENT, "property": &"adjustment_enabled", "value": true}]
	return []
