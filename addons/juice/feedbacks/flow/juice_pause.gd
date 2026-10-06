@tool
@icon("res://addons/juice/icons/flow.svg")
class_name JuicePause
extends JuiceFeedback
## Stops the sequence for a while. Feedbacks below it start only when it ends.
##
## The feedbacks above it keep running. Use [JuiceHoldingPause] to wait for them first.
## With [member script_driven] on, the sequence waits until [method JuicePlayer.resume] is called.

@export_group("Pause")
## How long the sequence waits, in seconds.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var pause_duration: float = 1.0
## Picks the duration at random between the two values below.
@export var randomize_pause_duration: bool = false
## The shortest random pause.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var min_pause_duration: float = 1.0
## The longest random pause.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var max_pause_duration: float = 3.0
## Rolls a new random duration each play instead of once when the player initializes.
@export var randomize_on_each_play: bool = true
## Waits until [method JuicePlayer.resume] is called instead of a timer.
@export var script_driven: bool = false
## Lets a script driven pause resume by itself after [member auto_resume_after].
@export var auto_resume: bool = false
## Seconds after which a script driven pause resumes by itself.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var auto_resume_after: float = 0.25

var _rolled_duration := -1.0


func _on_initialize() -> void:
	_roll()


func _on_play(_feedback_intensity: float) -> void:
	if randomize_on_each_play:
		_roll()


func _get_duration() -> float:
	if script_driven:
		return 0.0
	return _get_pause_duration()


func _get_pause_duration() -> float:
	if not randomize_pause_duration:
		return pause_duration
	if _rolled_duration < 0.0:
		return (min_pause_duration + max_pause_duration) * 0.5
	return _rolled_duration


func _is_pause() -> bool:
	return true


func _is_script_driven_pause() -> bool:
	return script_driven


func _get_auto_resume() -> float:
	return auto_resume_after if auto_resume else 0.0


func _get_category() -> StringName:
	return Juice.CATEGORY_OTHER


func _get_color() -> Color:
	return Color("54a0ff")


func _has_target() -> bool:
	return false


func _has_randomness() -> bool:
	return false


func _roll() -> void:
	if randomize_pause_duration:
		_rolled_duration = randf_range(minf(min_pause_duration, max_pause_duration), maxf(min_pause_duration, max_pause_duration))
