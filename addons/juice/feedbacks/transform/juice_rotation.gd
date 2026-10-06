@tool
@icon("res://addons/juice/icons/transform.svg")
class_name JuiceRotation
extends JuiceTransformBase
## Rotates a Node2D, Node3D or Control. Values are in degrees.
##
## 3D nodes use all three axes as Euler angles. 2D nodes and controls rotate around
## their only axis, which is the z value.


func _init() -> void:
	super()
	remap_one = Vector3(0.0, 0.0, 90.0)
	destination = Vector3(0.0, 0.0, 90.0)


func _is_supported(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control


func _read(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).rotation_degrees
	if node is Node2D:
		return Vector3(0.0, 0.0, (node as Node2D).rotation_degrees)
	return Vector3(0.0, 0.0, (node as Control).rotation_degrees)


func _write(node: Node, value: Vector3) -> void:
	if node is Node3D:
		(node as Node3D).rotation_degrees = value
	elif node is Node2D:
		(node as Node2D).rotation_degrees = value.z
	elif node is Control:
		(node as Control).rotation_degrees = value.z
