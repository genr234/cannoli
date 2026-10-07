@tool
@abstract
@icon("res://addons/behaviors/icons/area.svg")
class_name BehaviorAreaCondition
extends BehaviorCondition
## Base of [BehaviorHasEnteredArea] and [BehaviorHasExitedArea].
##
## Listens to the signals of an [Area2D] or [Area3D] from the moment the tree is built, so
## nothing is missed while other branches run. The condition succeeds once after each
## event, then goes back to failing until the next one.

## The area, relative to the actor. Empty uses the actor when it is an area, or its first
## area child.
@export var area_path: NodePath = NodePath()
## Only counts nodes in this group. Empty counts every node.
@export var group: StringName = &""
## Counts physics bodies.
@export var include_bodies: bool = true
## Counts other areas.
@export var include_areas: bool = true
## The variable that receives the node that entered or exited.
@export var store_node: String = ""

var _triggered: bool = false
var _other: Node
var _connected: Node


func _on_awake() -> void:
	_connect_area()


func _on_start() -> void:
	if _connected == null:
		_connect_area()


func _on_update(_delta: float) -> Status:
	if not _triggered:
		return Status.FAILURE
	if not store_node.is_empty():
		set_var(StringName(store_node), _other if is_instance_valid(_other) else null)
	return Status.SUCCESS


func _on_end() -> void:
	if status == Status.SUCCESS:
		_triggered = false
		_other = null


func _on_tree_complete(_tree_status: Status) -> void:
	_triggered = false
	_other = null


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not include_bodies and not include_areas:
		warnings.append("%s counts neither bodies nor areas." % get_display_name())
	return warnings


## True to listen for exits, false for entries.
func _is_exit() -> bool:
	return false


func _find_area() -> Node:
	if not area_path.is_empty():
		var node := get_node_from_actor(area_path)
		return node if node is Area2D or node is Area3D else null
	if actor is Area2D or actor is Area3D:
		return actor
	if actor:
		for child in actor.get_children():
			if child is Area2D or child is Area3D:
				return child
	return null


func _connect_area() -> void:
	var area := _find_area()
	if area == null:
		return
	_connected = area
	var suffix := "exited" if _is_exit() else "entered"
	if include_bodies:
		area.connect("body_" + suffix, _on_other)
	if include_areas:
		area.connect("area_" + suffix, _on_other)


func _on_other(other: Node) -> void:
	if not String(group).is_empty() and not other.is_in_group(group):
		return
	_triggered = true
	_other = other
