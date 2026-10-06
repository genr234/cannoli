@tool
@icon("res://addons/juice/icons/floating_text.svg")
class_name JuiceShowText
extends JuiceFeedback
## Asks a [JuiceFloatingTextSpawner] to show a floating text.
##
## The text is sent on the channel, so any spawner listening there shows it. Where it
## appears is the position the player was played at, or the position of the target node.
##
## The text can be fixed, or the number of the intensity of the play (handy for damage
## that scales with intensity). When the fixed text is a number, [member multiply_by_intensity]
## multiplies it by the intensity. [member format] wraps the final value, for example
## [code]+{value} XP[/code].
##
## Without a forced lifetime the feedback is instant. With one, it lasts that long, so a
## holding pause can wait for the text to disappear.

## Where the text starts.
enum PositionMode { PLAY_POSITION, TARGET_NODE }
## Where the displayed text comes from.
enum ValueSource { TEXT, INTENSITY }
## How a numeric value is rounded.
enum Rounding { NONE, ROUND, CEIL, FLOOR }

## The bus event sent to the spawners.
const EVENT := JuiceFloatingTextSpawner.EVENT

@export_group("Floating Text")
## Which text to show.
@export var value_source: ValueSource = ValueSource.TEXT:
	set(value):
		value_source = value
		notify_property_list_changed()
## The fixed text.
@export var text: String = "100"
## When the text is a number, multiplies it by the intensity of the play.
@export var multiply_by_intensity: bool = false
## Multiplies the value taken from the intensity.
@export var intensity_value_scale: float = 1.0
## Rounds a numeric value.
@export var rounding: Rounding = Rounding.NONE
## Wraps the text. [code]{value}[/code] is replaced by the text.
@export var format: String = "{value}"
## Sent to the spawner as its intensity, multiplied by the intensity of the play. A spawner
## can use it to change lifetime, distance and size.
@export var spawner_intensity: float = 1.0
## Makes the text bigger or smaller than the spawner's default.
@export_range(0.1, 5.0, 0.01, "or_greater") var size_multiplier: float = 1.0

@export_group("Look")
## Replaces the color of the text.
@export var force_color: bool = false:
	set(value):
		force_color = value
		notify_property_list_changed()
## The color to use.
@export var color: Color = Color.WHITE
## Replaces the gradient of the spawner with this one.
@export var use_gradient: bool = false:
	set(value):
		use_gradient = value
		notify_property_list_changed()
## The color over the life of the text.
@export var gradient: Gradient
## Replaces the lifetime of the spawner.
@export var force_lifetime: bool = false:
	set(value):
		force_lifetime = value
		notify_property_list_changed()
## The lifetime to use.
@export_range(0.05, 10.0, 0.01, "or_greater", "suffix:s") var lifetime: float = 0.8

@export_group("Position")
## Where the text starts.
@export var position_mode: PositionMode = PositionMode.PLAY_POSITION
## Moved from that position by this much, in units.
@export var offset: Vector3 = Vector3.ZERO
## The direction the text floats in. Zero lets the spawner decide.
@export var direction: Vector3 = Vector3.ZERO
## Makes the text follow the target node while it floats.
@export var attach_to_target: bool = false


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name in ["text", "multiply_by_intensity"] and value_source != ValueSource.TEXT:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "intensity_value_scale" and value_source != ValueSource.INTENSITY:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "color" and not force_color:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "gradient" and not use_gradient:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "lifetime" and not force_lifetime:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return lifetime if force_lifetime else 0.0


func _get_category() -> StringName:
	return Juice.CATEGORY_OTHER


func _has_channel() -> bool:
	return true


func _has_target() -> bool:
	return position_mode == PositionMode.TARGET_NODE or attach_to_target


func _get_display_label() -> String:
	return "Show Text"


func _on_play(_feedback_intensity: float) -> void:
	var share := get_intensity()
	var spot := get_play_position()
	var node := get_target() if _has_target() else null
	if position_mode == PositionMode.TARGET_NODE and node != null:
		spot = Juice.node_position(node)
	var payload: Dictionary = {
		"text": _build_text(share),
		"position": spot + offset,
		"direction": direction,
		"intensity": spawner_intensity * share,
		"size": size_multiplier,
	}
	if force_color:
		payload["color"] = color
	if use_gradient and gradient != null:
		payload["gradient"] = gradient
	if force_lifetime:
		payload["lifetime"] = lifetime
	if attach_to_target and node != null:
		payload["attach"] = node
	broadcast(EVENT, payload)


func _build_text(share: float) -> String:
	var shown := ""
	if value_source == ValueSource.INTENSITY:
		shown = _number_to_text(_round(share * intensity_value_scale))
	elif multiply_by_intensity and text.is_valid_float():
		shown = _number_to_text(_round(text.to_float() * share))
	else:
		shown = text
	return format.replace("{value}", shown)


func _round(number: float) -> float:
	match rounding:
		Rounding.ROUND:
			return roundf(number)
		Rounding.CEIL:
			return ceilf(number)
		Rounding.FLOOR:
			return floorf(number)
	return number


func _number_to_text(number: float) -> String:
	return JuiceFloatingTextSpawner.number_to_text(number)
