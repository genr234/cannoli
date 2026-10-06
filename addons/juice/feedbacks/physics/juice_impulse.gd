@tool
@icon("res://addons/juice/icons/physics.svg")
class_name JuiceImpulse
extends JuiceFeedback
## Pushes or spins physics bodies, for example a knockback or a pop-up.
##
## Works on RigidBody2D and RigidBody3D, and adds to the velocity of CharacterBody2D
## and CharacterBody3D. The strength is picked at random between a minimum and a
## maximum on each axis. Intensity multiplies it. 2D bodies use the x and y values
## (and z for torque).

## IMPULSE is one instant push that depends on mass. VELOCITY_CHANGE adds to the velocity
## and ignores mass. FORCE pushes every frame for [member force_duration]. TORQUE_IMPULSE
## and TORQUE do the same as IMPULSE and FORCE, but spin the body.
enum Action { IMPULSE, VELOCITY_CHANGE, FORCE, TORQUE_IMPULSE, TORQUE }

@export_group("Impulse")
## What to do to the bodies.
@export var action: Action = Action.IMPULSE:
	set(value):
		action = value
		notify_property_list_changed()
## The weakest value on each axis.
@export var min_strength: Vector3 = Vector3.ZERO
## The strongest value on each axis.
@export var max_strength: Vector3 = Vector3(0.0, 10.0, 0.0)
## Seconds a FORCE or TORQUE is applied for.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var force_duration: float = 0.2
## Reads the strength in the local space of each body instead of the world space.
@export var local_space: bool = false
## Uses only the length of the strength and pushes it along the front of the body
## (-Z in 3D, +X in 2D).
@export var forward_force: bool = false
## Sets the velocity of the body to zero before the push.
@export var reset_velocity_first: bool = false
## More bodies to push besides the target. Paths are relative to the player.
@export var extra_targets: Array[NodePath] = []

var _strength := Vector3.ZERO


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "force_duration" and action != Action.FORCE and action != Action.TORQUE:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return force_duration if action == Action.FORCE or action == Action.TORQUE else 0.0


func _on_play(_feedback_intensity: float) -> void:
	if Engine.is_editor_hint():
		return
	_strength = Vector3(
		randf_range(min_strength.x, max_strength.x),
		randf_range(min_strength.y, max_strength.y),
		randf_range(min_strength.z, max_strength.z)) * get_intensity()
	for body in _bodies():
		if reset_velocity_first:
			_reset_velocity(body)
		if action == Action.FORCE or action == Action.TORQUE:
			continue
		_apply(body, 0.0)


func _on_tick() -> void:
	if Engine.is_editor_hint() or (action != Action.FORCE and action != Action.TORQUE):
		return
	for body in _bodies():
		_apply(body, get_delta())


func _bodies() -> Array[Node]:
	var list: Array[Node] = []
	var main := get_target()
	if main != null:
		list.append(main)
	for path in extra_targets:
		var extra := resolve(path)
		if extra != null and not list.has(extra):
			list.append(extra)
	return list


func _reset_velocity(body: Node) -> void:
	if body is RigidBody3D:
		(body as RigidBody3D).linear_velocity = Vector3.ZERO
		(body as RigidBody3D).angular_velocity = Vector3.ZERO
	elif body is RigidBody2D:
		(body as RigidBody2D).linear_velocity = Vector2.ZERO
		(body as RigidBody2D).angular_velocity = 0.0
	elif body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	elif body is CharacterBody2D:
		(body as CharacterBody2D).velocity = Vector2.ZERO


# Applies the strength to one body. [param delta] is the frame time for FORCE (the
# velocity of a character body grows by strength x delta), and 0 for one shot actions.
func _apply(body: Node, delta: float) -> void:
	if body is Node3D:
		var node_3d := body as Node3D
		var vector := _strength
		if forward_force:
			vector = -node_3d.global_basis.z.normalized() * _strength.length()
		elif local_space:
			vector = node_3d.global_basis * _strength
		_apply_3d(body, vector, delta)
	elif body is Node2D:
		var node_2d := body as Node2D
		var vector_2d := Vector2(_strength.x, _strength.y)
		if forward_force:
			vector_2d = Vector2.RIGHT.rotated(node_2d.global_rotation) * vector_2d.length()
		elif local_space:
			vector_2d = vector_2d.rotated(node_2d.global_rotation)
		_apply_2d(body, vector_2d, _strength.z, delta)


func _apply_3d(body: Node, vector: Vector3, delta: float) -> void:
	if body is RigidBody3D:
		var rigid := body as RigidBody3D
		match action:
			Action.IMPULSE:
				rigid.apply_central_impulse(vector)
			Action.VELOCITY_CHANGE:
				rigid.linear_velocity += vector
			Action.FORCE:
				rigid.apply_central_force(vector)
			Action.TORQUE_IMPULSE:
				rigid.apply_torque_impulse(vector)
			Action.TORQUE:
				rigid.apply_torque(vector)
	elif body is CharacterBody3D:
		var character := body as CharacterBody3D
		match action:
			Action.IMPULSE, Action.VELOCITY_CHANGE:
				character.velocity += vector
			Action.FORCE:
				character.velocity += vector * delta


func _apply_2d(body: Node, vector: Vector2, torque: float, delta: float) -> void:
	if body is RigidBody2D:
		var rigid := body as RigidBody2D
		match action:
			Action.IMPULSE:
				rigid.apply_central_impulse(vector)
			Action.VELOCITY_CHANGE:
				rigid.linear_velocity += vector
			Action.FORCE:
				rigid.apply_central_force(vector)
			Action.TORQUE_IMPULSE:
				rigid.apply_torque_impulse(torque)
			Action.TORQUE:
				rigid.apply_torque(torque)
	elif body is CharacterBody2D:
		var character := body as CharacterBody2D
		match action:
			Action.IMPULSE, Action.VELOCITY_CHANGE:
				character.velocity += vector
			Action.FORCE:
				character.velocity += vector * delta
