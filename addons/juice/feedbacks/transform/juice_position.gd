@tool
@icon("res://addons/juice/icons/transform.svg")
class_name JuicePosition
extends JuiceTransformBase
## Moves a Node2D, Node3D or Control.
##
## Values are in pixels for 2D nodes and controls and in units for 3D nodes.

## LOCAL uses the position relative to the parent. GLOBAL uses the world position.
enum Space { LOCAL, GLOBAL }

## Which position is animated.
@export var space: Space = Space.LOCAL


func _is_supported(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control


func _read(node: Node) -> Vector3:
	if node is Node3D:
		var node_3d := node as Node3D
		return node_3d.position if space == Space.LOCAL else node_3d.global_position
	if node is Node2D:
		var node_2d := node as Node2D
		var point := node_2d.position if space == Space.LOCAL else node_2d.global_position
		return Vector3(point.x, point.y, 0.0)
	var control := node as Control
	var control_point := control.position if space == Space.LOCAL else control.global_position
	return Vector3(control_point.x, control_point.y, 0.0)


func _write(node: Node, value: Vector3) -> void:
	if node is Node3D:
		if space == Space.LOCAL:
			(node as Node3D).position = value
		else:
			(node as Node3D).global_position = value
	elif node is Node2D:
		if space == Space.LOCAL:
			(node as Node2D).position = Vector2(value.x, value.y)
		else:
			(node as Node2D).global_position = Vector2(value.x, value.y)
	elif node is Control:
		if space == Space.LOCAL:
			(node as Control).position = Vector2(value.x, value.y)
		else:
			(node as Control).global_position = Vector2(value.x, value.y)
