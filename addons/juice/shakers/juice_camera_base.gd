@tool
@icon("res://addons/juice/icons/camera.svg")
@abstract
class_name JuiceCameraBase
extends JuiceShaker
## The shared part of the camera shakers.
##
## The target is a [Camera2D] or a [Camera3D]. When [member JuiceShaker.target] is empty
## and the parent is not a camera, the shaker uses the current camera of its viewport.


func get_target_node() -> Node:
	var node := super.get_target_node()
	if node is Camera2D or node is Camera3D:
		return node
	var viewport := get_viewport()
	if viewport == null:
		return null
	if node is Node3D:
		return viewport.get_camera_3d() if viewport.get_camera_3d() != null else viewport.get_camera_2d()
	return viewport.get_camera_2d() if viewport.get_camera_2d() != null else viewport.get_camera_3d()


func _is_target_supported(node: Node) -> bool:
	return node is Camera2D or node is Camera3D
