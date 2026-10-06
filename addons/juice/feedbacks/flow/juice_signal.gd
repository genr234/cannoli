@tool
@icon("res://addons/juice/icons/flow.svg")
class_name JuiceSignal
extends JuiceFeedback
## Tells the rest of the game that the sequence reached this point.
##
## It can emit [signal JuicePlayer.triggered] with an id, and call a method on its
## target node. The target is the node set in the Target group.

@export_group("Signal")
## The id sent with [signal JuicePlayer.triggered].
@export var signal_id: StringName = &""
## Emits [signal JuicePlayer.triggered] on the player.
@export var emit_on_player: bool = true
## Calls [member method_name] on the target node.
@export var call_method: bool = false
## The method to call on the target.
@export var method_name: StringName = &""
## The arguments passed to the method.
@export var method_args: Array = []
## Appends the intensity of this play as the last argument.
@export var pass_intensity: bool = false


func _on_play(feedback_intensity: float) -> void:
	if emit_on_player and player != null:
		player.triggered.emit(signal_id)
	if not call_method or method_name.is_empty():
		return
	var node := get_target()
	if node == null or not node.has_method(method_name):
		push_warning("JuiceSignal: '%s' has no method '%s'." % [node, method_name])
		return
	var args := method_args.duplicate()
	if pass_intensity:
		args.append(feedback_intensity)
	node.callv(method_name, args)


func _has_randomness() -> bool:
	return false


func _get_color() -> Color:
	return Color("ff9ff3")
