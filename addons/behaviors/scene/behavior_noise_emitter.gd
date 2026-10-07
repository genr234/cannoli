@tool
@icon("res://addons/behaviors/icons/noise_emitter.svg")
class_name BehaviorNoiseEmitter
extends Node
## Makes noises at its parent's position for [BehaviorCanHear] conditions to hear.
##
## Call [method emit] from code, or set [member signal_name] to make a noise whenever
## a signal fires, such as a footstep or a gunshot. The parent can be a [Node2D] or a
## [Node3D].

## How far a noise carries, in world units.
@export_range(0.0, 10000.0, 0.01, "or_greater", "suffix:units") var radius: float = 10.0
## A label that [BehaviorCanHear] can filter by.
@export var tag: StringName = &""
## The node whose signal makes a noise, relative to this node. Empty uses the parent.
@export var signal_source: NodePath = NodePath()
## The signal that makes a noise. Empty makes no noise by itself.
@export var signal_name: StringName = &""


func _ready() -> void:
	if Engine.is_editor_hint() or String(signal_name).is_empty():
		return
	var source := get_node_or_null(signal_source) if not signal_source.is_empty() else get_parent()
	if source == null or not source.has_signal(signal_name):
		push_warning("BehaviorNoiseEmitter \"%s\": the signal \"%s\" does not exist." % [name, signal_name])
		return
	var arguments := 0
	for info in source.get_signal_list():
		if info.name == signal_name:
			arguments = info.args.size()
			break
	source.connect(signal_name, _on_signal.unbind(arguments) if arguments > 0 else _on_signal)


## Makes a noise at the parent's position. A negative [param noise_radius] uses
## [member radius], and an empty [param noise_tag] uses [member tag].
func emit(noise_radius: float = -1.0, noise_tag: StringName = &"") -> void:
	var parent := get_parent()
	var position: Variant = null
	if parent is Node2D:
		position = (parent as Node2D).global_position
	elif parent is Node3D:
		position = (parent as Node3D).global_position
	if position == null:
		return
	Behaviors.emit_noise(parent, position, radius if noise_radius < 0.0 else noise_radius, tag if String(noise_tag).is_empty() else noise_tag)


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not (get_parent() is Node2D or get_parent() is Node3D):
		warnings.append("The parent must be a Node2D or a Node3D, so the noise has a position.")
	return warnings


func _on_signal() -> void:
	emit()
