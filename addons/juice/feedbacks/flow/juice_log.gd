@tool
@icon("res://addons/juice/icons/flow.svg")
class_name JuiceLog
extends JuiceFeedback
## Prints a message when reached. Useful for checking the order of a sequence.

enum Level { INFO, WARNING, ERROR }

@export_group("Log")
## The text to print.
@export var message: String = "Juice"
## How the message is reported.
@export var level: Level = Level.INFO
## Adds the player name and the time since the play started.
@export var include_context: bool = true


func _on_play(feedback_intensity: float) -> void:
	var text := message
	if include_context and player != null:
		text = "[%s %.3fs, intensity %.2f] %s" % [player.name, player.get_elapsed_time(), feedback_intensity, message]
	match level:
		Level.WARNING:
			push_warning(text)
		Level.ERROR:
			push_error(text)
		_:
			print(text)


func _has_randomness() -> bool:
	return false


func _has_target() -> bool:
	return false


func _get_color() -> Color:
	return Color("c8d6e5")
