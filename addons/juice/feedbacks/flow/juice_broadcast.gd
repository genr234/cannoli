@tool
@icon("res://addons/juice/icons/flow.svg")
class_name JuiceBroadcast
extends JuiceFeedback
## Sends a named event with a number on the Juice bus.
##
## Anything that listens to the event name on the same channel receives it: a
## [JuiceListener], or your own code through [method Juice.listen]. Use it to drive
## things that cannot be referenced from the player, such as a music mixer, a screen
## effect or another scene.
##
## The payload holds the usual keys of [method JuiceFeedback.broadcast] plus:
## [code]event[/code] (the name), [code]value[/code] (float), [code]progress[/code]
## (0..1 for OVER_TIME, otherwise 1), [code]phase[/code] ([code]&"play"[/code],
## [code]&"progress"[/code] or [code]&"stop"[/code]) and everything in [member extra].

## INSTANT sends [member value] once. OVER_TIME sends a new value on every frame for
## [member duration] seconds, following the curve.
enum Mode { INSTANT, OVER_TIME }

@export_group("Broadcast")
## The name of the event.
@export var event_name: StringName = &"juice_event"
## How the value is sent.
@export var mode: Mode = Mode.INSTANT:
	set(value):
		mode = value
		notify_property_list_changed()
## The value sent by INSTANT.
@export var value: float = 1.0
## Seconds OVER_TIME lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## The curve of the value. Null is a straight line.
@export var tween: JuiceTween
## The value a curve value of 0 maps to.
@export var remap_zero: float = 0.0
## The value a curve value of 1 maps to.
@export var remap_one: float = 1.0
## Sends the event one more time when the player is stopped.
@export var send_on_stop: bool = false
## More data added to the payload.
@export var extra: Dictionary = {}


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "value" and mode != Mode.INSTANT:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["duration", "tween", "remap_zero", "remap_one"] and mode != Mode.OVER_TIME:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _has_channel() -> bool:
	return true


func _has_range() -> bool:
	return true


func _has_target() -> bool:
	return false


func _has_randomness() -> bool:
	return false


func _get_color() -> Color:
	return Color("ff9ff3")


func _get_duration() -> float:
	return duration if mode == Mode.OVER_TIME else 0.0


func _on_play(_feedback_intensity: float) -> void:
	if mode == Mode.INSTANT:
		_send(&"play", value, 1.0)


func _on_progress(progress: float) -> void:
	_send(&"progress", lerpf(remap_zero, remap_one, JuiceTween.sample(tween, progress)), progress)


func _on_stop() -> void:
	if send_on_stop:
		_send(&"stop", value if mode == Mode.INSTANT else remap_zero, 1.0)


func _send(phase: StringName, sent_value: float, progress: float) -> void:
	if event_name.is_empty():
		return
	var data := {"event": event_name, "value": sent_value, "progress": progress, "phase": phase}
	data.merge(extra, true)
	broadcast(event_name, data)
