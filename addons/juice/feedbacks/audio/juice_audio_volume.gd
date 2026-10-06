@tool
@icon("res://addons/juice/icons/sound.svg")
class_name JuiceAudioVolume
extends JuiceFeedback
## Animates the volume of an AudioStreamPlayer, AudioStreamPlayer2D or AudioStreamPlayer3D,
## for fades and ducking.
##
## Intensity is the share of the change that shows. The original volume is restored on restore.

## ABSOLUTE runs from [member from_volume] to [member to_volume]. FROM_CURRENT runs from the
## volume the player had when the play started to [member to_volume].
enum Mode { ABSOLUTE, FROM_CURRENT }
## The unit of the volume values. Linear fades sound smoother to the ear than decibels near silence.
enum Unit { LINEAR, DECIBELS }

@export_group("Volume")
## How the values are used.
@export var mode: Mode = Mode.FROM_CURRENT:
	set(value):
		mode = value
		notify_property_list_changed()
## The unit of the values below.
@export var unit: Unit = Unit.LINEAR
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var duration: float = 1.0
## The curve of the change. Null is a straight line.
@export var tween: JuiceTween
## The volume at the start for ABSOLUTE. 1 is full volume when linear.
@export_range(-80.0, 24.0, 0.01, "or_greater") var from_volume: float = 1.0
## The volume at the end. 0 is silent when linear.
@export_range(-80.0, 24.0, 0.01, "or_greater") var to_volume: float = 0.0

var _initial := 0.0
var _origin := 0.0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "from_volume" and mode == Mode.FROM_CURRENT:
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
		_initial = node.get("volume_db")
		_origin = _initial


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _is_supported(node):
		return
	if not is_retrigger():
		_origin = node.get("volume_db")
	if duration <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target()
	if _is_supported(node):
		_apply(node, progress)


func _on_restore() -> void:
	var node := get_target()
	if _is_supported(node):
		node.set("volume_db", _initial)


func _apply(node: Node, progress: float) -> void:
	var shaped := JuiceTween.sample(tween, progress)
	var start_db := _origin if mode == Mode.FROM_CURRENT else _to_db(from_volume)
	var end_db := _to_db(to_volume)
	var db: float
	if unit == Unit.LINEAR:
		db = _linear_to_db_safe(lerpf(db_to_linear(start_db), db_to_linear(end_db), shaped))
	else:
		db = lerpf(start_db, end_db, shaped)
	node.set("volume_db", lerpf(_origin, db, get_intensity()))


func _to_db(value: float) -> float:
	return _linear_to_db_safe(value) if unit == Unit.LINEAR else value


# Silence maps to -80 dB, the bottom of the volume range, instead of minus infinity.
func _linear_to_db_safe(value: float) -> float:
	return maxf(linear_to_db(maxf(value, 0.0)), -80.0)


func _is_supported(node: Node) -> bool:
	return node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D
