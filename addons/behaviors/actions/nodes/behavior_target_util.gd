@tool
extends RefCounted
## Shared helpers for tasks that act on a node or object: finding it, and warning once.
##
## Not a task. Tasks load it with [code]preload[/code].


## Finds the object a task works on. A set [param variable] wins and must hold an
## object. Otherwise [param path] is resolved from the actor, and an empty path is the
## actor itself. Returns null when nothing valid is found.
static func resolve(task: BehaviorTask, path: NodePath, variable: String = "") -> Object:
	if not variable.is_empty():
		var held: Variant = task.get_var(StringName(variable))
		if typeof(held) == TYPE_OBJECT and is_instance_valid(held):
			return held
		return null
	return task.get_node_from_actor(path)


## Pushes a warning, but only the first time for this task. Keeps broken setups from
## flooding the log every tick.
static func warn_once(task: BehaviorTask, message: String) -> void:
	if task.has_meta(&"_warned"):
		return
	task.set_meta(&"_warned", true)
	push_warning("%s: %s" % [task.get_display_name(), message])


## True for the three audio player nodes.
static func is_audio_player(object: Object) -> bool:
	return object is AudioStreamPlayer or object is AudioStreamPlayer2D or object is AudioStreamPlayer3D


## The world position of a 2D or 3D node, or null for anything else.
static func get_position_of(node: Object) -> Variant:
	if node is Node2D or node is Control:
		return node.global_position
	if node is Node3D:
		return node.global_position
	return null


## Whether [param object] has the property at the start of [param property], which may
## be an indexed path such as [code]position:x[/code].
static func has_property(object: Object, property: String) -> bool:
	return property.get_slice(":", 0) in object
