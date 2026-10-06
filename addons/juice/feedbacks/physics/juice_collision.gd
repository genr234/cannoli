@tool
@icon("res://addons/juice/icons/physics.svg")
class_name JuiceCollision
extends JuiceFeedback
## Turns collision on or off, for example to make a node untouchable while it flashes.
##
## It works on CollisionShape2D/3D and CollisionPolygon2D/3D directly. On a body or an
## Area it changes all its shapes, or the monitoring flags of an Area. Restoring puts
## everything back. Nothing happens in the editor.

enum Action { ENABLE, DISABLE, TOGGLE }
## What is changed on a body or an Area. SHAPES changes the shapes among its children.
## MONITORING and MONITORABLE only apply to an Area.
enum Scope { SHAPES, MONITORING, MONITORABLE, MONITORING_AND_MONITORABLE }

@export_group("Collision")
## What to do.
@export var action: Action = Action.DISABLE
## What to change when the target is a body or an Area.
@export var scope: Scope = Scope.SHAPES
## Seconds the change lasts before it is put back. 0 keeps the change.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var hold_time: float = 0.0
## More nodes to change besides the target. Paths are relative to the player.
@export var extra_targets: Array[NodePath] = []

# Each entry is [object, property, inverted]. Inverted means the property is
# "disabled", so enabled is its opposite.
var _initial: Array = []
var _before: Array = []


func _get_duration() -> float:
	return hold_time


func _has_randomness() -> bool:
	return false


func _on_initialize() -> void:
	_initial = _snapshot()


func _on_play(_feedback_intensity: float) -> void:
	if Engine.is_editor_hint():
		return
	var entries := _entries()
	if not is_retrigger():
		_before = _values_of(entries)
	for entry: Array in entries:
		var enabled := _is_enabled(entry)
		match action:
			Action.ENABLE:
				_set_enabled(entry, true)
			Action.DISABLE:
				_set_enabled(entry, false)
			Action.TOGGLE:
				_set_enabled(entry, not enabled)


func _on_finished() -> void:
	if hold_time > 0.0 and not Engine.is_editor_hint():
		_put_back(_before)


func _on_restore() -> void:
	if not Engine.is_editor_hint():
		_put_back(_initial)


func _snapshot() -> Array:
	return _values_of(_entries())


func _values_of(entries: Array) -> Array:
	var values: Array = []
	for entry: Array in entries:
		values.append([entry, _is_enabled(entry)])
	return values


func _put_back(values: Array) -> void:
	for pair: Array in values:
		var entry: Array = pair[0]
		if is_instance_valid(entry[0]):
			_set_enabled(entry, pair[1])


func _entries() -> Array:
	var entries: Array = []
	_collect(get_target(), entries)
	for path in extra_targets:
		_collect(resolve(path), entries)
	return entries


func _collect(node: Node, entries: Array) -> void:
	if node == null:
		return
	if node is CollisionShape2D or node is CollisionShape3D or node is CollisionPolygon2D or node is CollisionPolygon3D:
		entries.append([node, &"disabled", true])
		return
	if node is Area2D or node is Area3D:
		if scope == Scope.MONITORING or scope == Scope.MONITORING_AND_MONITORABLE:
			entries.append([node, &"monitoring", false])
		if scope == Scope.MONITORABLE or scope == Scope.MONITORING_AND_MONITORABLE:
			entries.append([node, &"monitorable", false])
		if scope != Scope.SHAPES:
			return
	if node is CollisionObject2D or node is CollisionObject3D:
		for child in node.get_children():
			if child is CollisionShape2D or child is CollisionShape3D or child is CollisionPolygon2D or child is CollisionPolygon3D:
				entries.append([child, &"disabled", true])


func _is_enabled(entry: Array) -> bool:
	var value: bool = entry[0].get(entry[1])
	return not value if entry[2] else value


func _set_enabled(entry: Array, enabled: bool) -> void:
	var node: Object = entry[0]
	var value := not enabled if entry[2] else enabled
	# Physics state cannot change while the engine flushes physics queries.
	if Engine.is_in_physics_frame():
		node.set_deferred(entry[1], value)
	else:
		node.set(entry[1], value)
