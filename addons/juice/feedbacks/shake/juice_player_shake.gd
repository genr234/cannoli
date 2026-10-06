@tool
@icon("res://addons/juice/icons/shaker.svg")
class_name JuicePlayerShake
extends JuiceFeedback
## Starts the [JuicePlayer] of every [JuicePlayerShaker] on the same channel.
##
## Use it to run another player that this one cannot reference, for example a HUD reaction to a
## hit. The shaker passes the position and the intensity on. It is instant.
##
## Broadcasts [code]juice_play_player[/code]. It adds no payload keys to the common ones.


func _get_category() -> StringName:
	return Juice.CATEGORY_OTHER


func _has_channel() -> bool:
	return true


func _has_range() -> bool:
	return true


func _on_play(_feedback_intensity: float) -> void:
	broadcast(JuicePlayerShaker.EVENT)
