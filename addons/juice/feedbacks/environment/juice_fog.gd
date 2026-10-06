@tool
@icon("res://addons/juice/icons/environment.svg")
class_name JuiceFog
extends JuiceEnvironmentBase
## Animates the fog of the world [Environment], such as fog rolling in or a flash of
## volumetric light.
##
## Pick one fog value and the range to blend it over. Colors use the two color fields. Fog is
## switched on when the feedback plays, and volumetric fog too for the volumetric values.

## The fog value to animate.
enum Value {
	## The density of the fog.
	DENSITY,
	## The color of the fog light.
	LIGHT_COLOR,
	## How bright the fog light is.
	LIGHT_ENERGY,
	## How much the sun tints the fog.
	SUN_SCATTER,
	## How much the fog shows the sky.
	AERIAL_PERSPECTIVE,
	## How much the fog covers the sky.
	SKY_AFFECT,
	## The height where height fog starts.
	HEIGHT,
	## The density of height fog.
	HEIGHT_DENSITY,
	## The density of volumetric fog.
	VOLUMETRIC_DENSITY,
	## The color volumetric fog reflects.
	VOLUMETRIC_ALBEDO,
	## The color volumetric fog emits.
	VOLUMETRIC_EMISSION,
}

const _NAMES := {
	Value.DENSITY: &"fog_density",
	Value.LIGHT_COLOR: &"fog_light_color",
	Value.LIGHT_ENERGY: &"fog_light_energy",
	Value.SUN_SCATTER: &"fog_sun_scatter",
	Value.AERIAL_PERSPECTIVE: &"fog_aerial_perspective",
	Value.SKY_AFFECT: &"fog_sky_affect",
	Value.HEIGHT: &"fog_height",
	Value.HEIGHT_DENSITY: &"fog_height_density",
	Value.VOLUMETRIC_DENSITY: &"volumetric_fog_density",
	Value.VOLUMETRIC_ALBEDO: &"volumetric_fog_albedo",
	Value.VOLUMETRIC_EMISSION: &"volumetric_fog_emission",
}

@export_group("Fog")
## Which value to animate.
@export var value: Value = Value.DENSITY:
	set(new_value):
		value = new_value
		notify_property_list_changed()
## The value at curve position 0 for number values.
@export var from_value: float = 0.0
## The value at curve position 1 for number values.
@export var to_value: float = 0.05
## The color at curve position 0 for color values.
@export var from_color: Color = Color.WHITE
## The color at curve position 1 for color values.
@export var to_color: Color = Color.GRAY
## Turns fog on in the environment when the feedback plays.
@export var enable_fog: bool = true


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name in ["from_value", "to_value"] and _is_color():
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["from_color", "to_color"] and not _is_color():
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _is_color() -> bool:
	return value == Value.LIGHT_COLOR or value == Value.VOLUMETRIC_ALBEDO or value == Value.VOLUMETRIC_EMISSION


func _is_volumetric() -> bool:
	return value == Value.VOLUMETRIC_DENSITY or value == Value.VOLUMETRIC_ALBEDO or value == Value.VOLUMETRIC_EMISSION


func _get_changes() -> Array[Dictionary]:
	var from_v: Variant = from_color if _is_color() else from_value
	var to_v: Variant = to_color if _is_color() else to_value
	return [{"holder": _ENVIRONMENT, "property": _NAMES[value], "from": from_v, "to": to_v}]


func _get_switches() -> Array[Dictionary]:
	var switches: Array[Dictionary] = []
	if _is_volumetric():
		switches.append({"holder": _ENVIRONMENT, "property": &"volumetric_fog_enabled", "value": true})
	elif enable_fog:
		switches.append({"holder": _ENVIRONMENT, "property": &"fog_enabled", "value": true})
	return switches
