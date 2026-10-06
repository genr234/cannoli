@tool
@icon("res://addons/juice/icons/flow.svg")
class_name JuicePlayerControl
extends JuiceFeedback
## Tells other players what to do: play, stop, pause, restore and so on.
##
## The players are given as paths relative to this feedback's player. The feedback can
## also wait until the played players are done, so the sequence continues afterwards.

enum Mode {
	PLAY,
	STOP,
	PAUSE,
	RESUME,
	INITIALIZE,
	PLAY_REVERSED,
	PLAY_ONLY_IF_BACKWARD,
	PLAY_ONLY_IF_FORWARD,
	RESET_COOLDOWNS,
	FLIP_DIRECTION,
	SET_DIRECTION_FORWARD,
	SET_DIRECTION_BACKWARD,
	RESTORE,
	SKIP_TO_END,
}

@export_group("Player Control")
## The players to control. Paths are relative to the player of this feedback.
@export var target_players: Array[NodePath] = []
## What to tell them.
@export var mode: Mode = Mode.PLAY:
	set(value):
		mode = value
		notify_property_list_changed()
## Lasts as long as the longest played player, so a pause below waits for them.
@export var wait_for_players: bool = true
## Sends the intensity of this feedback along when playing.
@export var pass_intensity: bool = true


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "wait_for_players" and not _plays():
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif property.name == "pass_intensity" and not _plays():
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _has_target() -> bool:
	return false


func _has_randomness() -> bool:
	return false


func _get_color() -> Color:
	return Color("ff9ff3")


func _get_duration() -> float:
	if not wait_for_players or not _plays() or player == null:
		return 0.0
	var longest := 0.0
	for controlled in _players():
		longest = maxf(longest, controlled.get_total_duration())
	return longest


func _on_play(feedback_intensity: float) -> void:
	var scale := feedback_intensity if pass_intensity else 1.0
	var at := get_play_position()
	for controlled in _players():
		match mode:
			Mode.PLAY:
				controlled.play(at, scale)
			Mode.STOP:
				controlled.stop()
			Mode.PAUSE:
				controlled.pause()
			Mode.RESUME:
				controlled.resume()
			Mode.INITIALIZE:
				controlled.initialize(true)
			Mode.PLAY_REVERSED:
				controlled.play_reversed(at, scale)
			Mode.PLAY_ONLY_IF_BACKWARD:
				if controlled.direction == Juice.Direction.BACKWARD:
					controlled.play(at, scale)
			Mode.PLAY_ONLY_IF_FORWARD:
				if controlled.direction == Juice.Direction.FORWARD:
					controlled.play(at, scale)
			Mode.RESET_COOLDOWNS:
				controlled.reset_cooldowns()
			Mode.FLIP_DIRECTION:
				controlled.flip_direction()
			Mode.SET_DIRECTION_FORWARD:
				controlled.set_direction(Juice.Direction.FORWARD)
			Mode.SET_DIRECTION_BACKWARD:
				controlled.set_direction(Juice.Direction.BACKWARD)
			Mode.RESTORE:
				controlled.restore_initial_values()
			Mode.SKIP_TO_END:
				controlled.skip_to_end()


func _plays() -> bool:
	return mode == Mode.PLAY or mode == Mode.PLAY_REVERSED \
			or mode == Mode.PLAY_ONLY_IF_BACKWARD or mode == Mode.PLAY_ONLY_IF_FORWARD


# The controlled players that exist. The player of this feedback is skipped, because
# playing yourself would never end.
func _players() -> Array[JuicePlayer]:
	var list: Array[JuicePlayer] = []
	for path in target_players:
		var found := resolve(path) as JuicePlayer
		if found != null and found != player and not list.has(found):
			list.append(found)
	return list
