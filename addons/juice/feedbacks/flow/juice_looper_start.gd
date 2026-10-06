@tool
@icon("res://addons/juice/icons/flow.svg")
class_name JuiceLooperStart
extends JuicePause
## Marks where a [JuiceLooper] below it jumps back to.
##
## It can also pause. By default its pause is 0 seconds.


func _init() -> void:
	pause_duration = 0.0


func _is_looper_start() -> bool:
	return true


func _get_color() -> Color:
	return Color("1dd1a1")
