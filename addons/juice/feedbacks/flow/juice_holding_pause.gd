@tool
@icon("res://addons/juice/icons/flow.svg")
class_name JuiceHoldingPause
extends JuicePause
## Waits for the feedbacks above it to finish, then pauses the sequence.
##
## The wait lasts as long as the longest earlier feedback, counting its delay and
## repeats. Feedbacks marked excluded from holding pauses are not waited for.


func _is_holding_pause() -> bool:
	return true


func _get_color() -> Color:
	return Color("2e86de")
