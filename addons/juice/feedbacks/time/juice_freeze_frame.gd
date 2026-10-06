@tool
@icon("res://addons/juice/icons/time.svg")
class_name JuiceFreezeFrame
extends JuiceFeedback
## A hit stop: freezes the game, or only some nodes, for a short moment.
##
## GLOBAL sets [member Engine.time_scale] to [member freeze_scale] through [JuiceTimeScaleStack],
## so it can overlap with other time feedbacks. LOCAL freezes only the nodes in
## [member targets_to_freeze]: their process mode is set to disabled, and GPU particles
## below them stop animating, while the rest of the game keeps running. The feedback runs in
## unscaled time. Nothing happens in the editor preview.

## What gets frozen.
enum Scope {
	## The whole game.
	GLOBAL,
	## Only the nodes listed in [member targets_to_freeze].
	LOCAL,
}

@export_group("Freeze Frame")
## Freeze everything, or only some nodes.
@export var scope: Scope = Scope.GLOBAL:
	set(value):
		scope = value
		notify_property_list_changed()
## Seconds the freeze lasts.
@export_range(0.0, 2.0, 0.005, "or_greater", "suffix:s") var duration: float = 0.08
## The speed during a GLOBAL freeze. 0 stops everything.
@export_range(0.0, 1.0, 0.001) var freeze_scale: float = 0.0
@export_group("Local Freeze")
## The nodes to freeze, relative to the player. Their children freeze with them unless a child
## has its own process mode. A node that holds the player itself is skipped.
@export var targets_to_freeze: Array[NodePath] = []

# instance id -> {process_mode, speed_scales: {particle id: float}}
var _frozen: Dictionary = {}
var _key := 0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "timescale_mode":
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "freeze_scale" and scope != Scope.GLOBAL:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["Local Freeze", "targets_to_freeze"] and scope != Scope.LOCAL:
		if property.usage & PROPERTY_USAGE_GROUP:
			property.usage = PROPERTY_USAGE_NONE
		else:
			property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_TIME


func _has_target() -> bool:
	return false


func _on_initialize() -> void:
	timescale_mode = Juice.TimeMode.UNSCALED
	_key = get_instance_id()


func _on_play(_feedback_intensity: float) -> void:
	timescale_mode = Juice.TimeMode.UNSCALED
	if Engine.is_editor_hint() or get_intensity() <= 0.0:
		return
	if scope == Scope.GLOBAL:
		JuiceTimeScaleStack.set_entry(_key, freeze_scale)
	else:
		_freeze_locals()


func _on_finished() -> void:
	_thaw()


func _on_skip_to_end() -> void:
	_thaw()


func _on_stop() -> void:
	_thaw()


func _on_restore() -> void:
	_thaw()


func _freeze_locals() -> void:
	for path in targets_to_freeze:
		var node := resolve(path)
		if node == null or _frozen.has(node.get_instance_id()):
			continue
		if node == player or node.is_ancestor_of(player):
			continue
		var saved := {"process_mode": node.process_mode, "speed_scales": {}}
		for particle in _gpu_particles(node):
			saved["speed_scales"][particle.get_instance_id()] = particle.get("speed_scale")
			particle.set("speed_scale", 0.0)
		node.process_mode = Node.PROCESS_MODE_DISABLED
		_frozen[node.get_instance_id()] = saved


func _thaw() -> void:
	JuiceTimeScaleStack.remove_entry(_key)
	for id: int in _frozen:
		var node := instance_from_id(id) as Node
		if node == null:
			continue
		var saved: Dictionary = _frozen[id]
		node.process_mode = saved["process_mode"]
		for particle_id: int in saved["speed_scales"]:
			var particle := instance_from_id(particle_id) as Node
			if particle != null:
				particle.set("speed_scale", saved["speed_scales"][particle_id])
	_frozen.clear()


func _gpu_particles(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	if root is GPUParticles2D or root is GPUParticles3D:
		found.append(root)
	for child in root.find_children("*", "", true, false):
		if child is GPUParticles2D or child is GPUParticles3D:
			found.append(child)
	return found
