@tool
@icon("res://addons/juice/icons/sound.svg")
class_name JuiceAudioPitch
extends JuiceFeedback
## Animates the pitch of an AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D.
##
## Intensity is the share of the change that shows. The original pitch is restored on restore.

## ABSOLUTE runs from [member from_pitch] to [member to_pitch]. FROM_CURRENT runs from the
## pitch the player had when the play started to [member to_pitch].
enum Mode { ABSOLUTE, FROM_CURRENT }

@export_group("Pitch")
## How the values are used.
@export var mode: Mode = Mode.ABSOLUTE:
	set(value):
		mode = value
		notify_property_list_changed()
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## The curve of the change. Null is a straight line.
@export var tween: JuiceTween
## The pitch scale at the start for ABSOLUTE.
@export_range(0.05, 4.0, 0.01, "or_greater") var from_pitch: float = 1.0
## The pitch scale at the end.
@export_range(0.05, 4.0, 0.01, "or_greater") var to_pitch: float = 0.5

var _initial := 1.0
var _origin := 1.0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "from_pitch" and mode == Mode.FROM_CURRENT:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_AUDIO


func _has_target() -> bool:
	return true


func _on_initialize() -> void:
	var node := get_target()
	if _is_supported(node):
		_initial = node.get("pitch_scale")
		_origin = _initial


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	if not is_retrigger():
		_origin = node.get("pitch_scale")
	if duration <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target()
	if _is_supported(node):
		_apply(node, progress)


func _on_restore() -> void:
	var node := get_target()
	if _is_supported(node):
		node.set("pitch_scale", _initial)


func _apply(node: Node, progress: float) -> void:
	var start := _origin if mode == Mode.FROM_CURRENT else from_pitch
	var value := lerpf(start, to_pitch, JuiceTween.sample(tween, progress))
	node.set("pitch_scale", maxf(lerpf(_origin, value, get_intensity()), 0.01))


func _is_supported(node: Node) -> bool:
	return node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D
