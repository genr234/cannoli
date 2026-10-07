@tool
@icon("res://addons/behaviors/icons/signal.svg")
class_name BehaviorEmitSignal
extends BehaviorAction
## Emits a signal on a node, then succeeds. Fails when the target or the signal is
## missing.

## The node that emits the signal, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the object that emits the signal. Replaces [member target] when
## set.
@export var target_variable: String = ""
## The signal to emit.
@export var signal_name: StringName = &""
## Values sent with the signal.
@export var arguments: Array = []
## Variables whose values are sent after [member arguments].
@export var argument_variables: PackedStringArray = PackedStringArray()

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var source := Targets.resolve(self, target, target_variable)
	if source == null or not source.has_signal(signal_name):
		return Status.FAILURE
	var args: Array = [signal_name]
	args.append_array(arguments)
	for variable in argument_variables:
		args.append(get_var(StringName(variable)))
	source.callv(&"emit_signal", args)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(signal_name).is_empty():
		warnings.append("Emit Signal has no signal name.")
	return warnings


func _get_graph_text() -> String:
	return String(signal_name)
