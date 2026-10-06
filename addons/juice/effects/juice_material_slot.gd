class_name JuiceMaterialSlot
extends RefCounted
## Finds the material of a [CanvasItem] or [GeometryInstance3D] and optionally swaps in a
## private copy, so animating one node does not change every node that shares the material.
##
## For a 3D node the slot is the material override when there is one, otherwise surface 0
## of a [MeshInstance3D] (as a surface override). [method restore] puts back what the slot
## held before.

## The node whose material is used.
var node: Node
## The surface index used on a [MeshInstance3D], or -1 for the material override.
var surface: int = -1
## The material that is being edited. Null when the node has none.
var material: Material

var _held: Material
var _replaced := false


## Looks up the material of [param target]. With [param duplicate_material] a private copy is
## installed. Returns false when the node has no material to work on.
func bind(target: Node, surface_index: int = -1, duplicate_material: bool = true) -> bool:
	node = target
	surface = surface_index
	material = null
	_held = null
	_replaced = false
	if target is CanvasItem:
		_held = (target as CanvasItem).material
		material = _held
	elif target is GeometryInstance3D:
		var geometry := target as GeometryInstance3D
		if surface < 0:
			_held = geometry.material_override
			material = _held
			if material == null and geometry is MeshInstance3D:
				var mesh_node := geometry as MeshInstance3D
				if mesh_node.get_surface_override_material_count() > 0:
					surface = 0
					_held = mesh_node.get_surface_override_material(0)
					material = mesh_node.get_active_material(0)
		elif geometry is MeshInstance3D:
			var mesh_instance := geometry as MeshInstance3D
			if surface < mesh_instance.get_surface_override_material_count():
				_held = mesh_instance.get_surface_override_material(surface)
				material = mesh_instance.get_active_material(surface)
	if material == null:
		return false
	if duplicate_material:
		material = material.duplicate()
		_write(material)
		_replaced = true
	return true


## Puts the original material back. Does nothing when the slot did not replace it.
func restore() -> void:
	if _replaced and is_instance_valid(node):
		_write(_held)
		material = _held
		_replaced = false


## Puts [param value] on the node (null removes the material). [method restore] undoes it.
func assign(value: Material) -> void:
	_write(value)
	material = value
	_replaced = true


## True when the slot installed a private copy.
func is_private() -> bool:
	return _replaced


func _write(value: Material) -> void:
	if not is_instance_valid(node):
		return
	if node is CanvasItem:
		(node as CanvasItem).material = value
	elif node is MeshInstance3D and surface >= 0:
		(node as MeshInstance3D).set_surface_override_material(surface, value)
	elif node is GeometryInstance3D:
		(node as GeometryInstance3D).material_override = value
