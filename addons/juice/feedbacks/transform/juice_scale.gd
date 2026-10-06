@tool
@icon("res://addons/juice/icons/transform.svg")
class_name JuiceScale
extends JuiceTransformBase
## Scales a Node2D, Node3D or Control.
##
## 2D nodes and controls ignore the z axis.


func _init() -> void:
	super()
	remap_one = Vector3(0.3, 0.3, 0.3)


func _is_supported(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control


func _read(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).scale
	if node is Node2D:
		var scale_2d := (node as Node2D).scale
		return Vector3(scale_2d.x, scale_2d.y, 1.0)
	var control_scale := (node as Control).scale
	return Vector3(control_scale.x, control_scale.y, 1.0)


func _write(node: Node, value: Vector3) -> void:
	if node is Node3D:
		(node as Node3D).scale = value
	elif node is Node2D:
		(node as Node2D).scale = Vector2(value.x, value.y)
	elif node is Control:
		(node as Control).scale = Vector2(value.x, value.y)
