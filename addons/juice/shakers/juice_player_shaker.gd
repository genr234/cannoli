@tool
@icon("res://addons/juice/icons/shaker.svg")
class_name JuicePlayerShaker
extends JuiceShaker
## Plays a [JuicePlayer] when a feedback broadcasts to it.
##
## This is how one player triggers another without a reference between them, for example a
## hit effect on an enemy that must also start the player on the HUD. It listens to
## [code]juice_play_player[/code], sent by [JuicePlayerShake].
##
## The event carries the position and the intensity of the sender. They are passed on to
## the player that starts, so range and intensity keep working.
##
## It does not shake anything, so the shake settings of the base class do not matter, except
## for the channel, the cooldown and [member JuiceShaker.only_use_shaker_values].

const EVENT := &"juice_play_player"

## What to do to the player when the event arrives.
enum Action { PLAY, PLAY_REVERSED, STOP, RESTORE, SKIP_TO_END }

@export_group("Player")
## The player to control, relative to this shaker. Empty uses the first [JuicePlayer] child.
@export var player_path: NodePath = NodePath()
## What to do to the player.
@export var action: Action = Action.PLAY
## Passes the intensity of the sender on to the player.
@export var use_event_intensity: bool = true

var _busy: bool = false


func get_player() -> JuicePlayer:
	if not player_path.is_empty():
		return get_node_or_null(player_path) as JuicePlayer
	for child in get_children():
		if child is JuicePlayer:
			return child
	return null


func _get_events() -> Array[StringName]:
	return [EVENT]


func _receive(_event: StringName, payload: Dictionary, reach: float) -> void:
	# A player that sends to its own shaker would otherwise loop forever.
	if _busy or _cooldown_left > 0.0:
		return
	var target_player := get_player()
	if target_player == null:
		return
	_cooldown_left = cooldown_between_shakes
	if _cooldown_left > 0.0:
		wake()
	var strength := reach
	if use_event_intensity:
		strength *= float(payload.get("intensity", 1.0))
	_busy = true
	match action:
		Action.PLAY:
			target_player.play(payload.get("position", null), strength)
		Action.PLAY_REVERSED:
			target_player.play_reversed(payload.get("position", null), strength)
		Action.STOP:
			target_player.stop()
		Action.RESTORE:
			target_player.restore_initial_values()
		Action.SKIP_TO_END:
			target_player.skip_to_end()
	_busy = false


func stop() -> void:
	pass


func restore() -> void:
	pass
