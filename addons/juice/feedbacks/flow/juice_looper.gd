@tool
@icon("res://addons/juice/icons/flow.svg")
class_name JuiceLooper
extends JuicePause
## Sends the sequence back up the list, once or many times.
##
## When reached it waits for the running feedbacks to finish, then jumps back to
## the feedback after the nearest earlier pause or [JuiceLooperStart], or to the top.
## The player emits [signal JuicePlayer.loop] for each jump.

@export_group("Loop")
## Jump back to the last pause above this feedback.
@export var loop_at_last_pause: bool = true
## Jump back to the last looper start above this feedback.
@export var loop_at_last_looper_start: bool = true
## Loops until the player is stopped.
@export var infinite_loop: bool = false
## How many times the looped part runs in total.
@export_range(1, 100, 1, "or_greater") var number_of_loops: int = 2

var _loops_left := 0


func _init() -> void:
	pause_duration = 0.0


func _on_initialize() -> void:
	super._on_initialize()
	_loops_left = number_of_loops


func _on_reset() -> void:
	_loops_left = number_of_loops


func _on_play(feedback_intensity: float) -> void:
	super._on_play(feedback_intensity)
	_loops_left -= 1


func _is_looper() -> bool:
	return true


func _is_loop_pending() -> bool:
	return infinite_loop or _loops_left > 0


func _get_loop_count() -> int:
	return 0 if infinite_loop else number_of_loops


func _loops_to_last_pause() -> bool:
	return loop_at_last_pause


func _loops_to_last_looper_start() -> bool:
	return loop_at_last_looper_start


func _get_color() -> Color:
	return Color("10ac84")
