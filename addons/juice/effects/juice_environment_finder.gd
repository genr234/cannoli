class_name JuiceEnvironmentFinder
extends Object
## Finds the [Environment] and camera attributes that post effects should change.
##
## Search order: the given node itself when it is a [WorldEnvironment] or a [Camera3D];
## the current camera of its viewport; the first [WorldEnvironment] in the tree; the
## [World3D] of its viewport. The result is a dictionary with the keys
## [code]environment[/code], [code]attributes[/code], [code]attributes_host[/code] (the
## object that owns the attributes slot) and [code]attributes_property[/code].


## Looks up the environment and attributes. Every value may be null or empty.
static func find(start: Node) -> Dictionary:
	var result := {
		"environment": null,
		"attributes": null,
		"attributes_host": null,
		"attributes_property": &"",
	}
	if start == null or not start.is_inside_tree():
		return result
	var world_env: WorldEnvironment = start as WorldEnvironment
	var camera: Camera3D = start as Camera3D
	var viewport := start.get_viewport()
	if world_env == null and camera == null and viewport != null:
		camera = viewport.get_camera_3d()
		if camera != null and camera.environment == null and camera.attributes == null:
			camera = null
		if camera == null:
			world_env = _first_world_environment(start)
	var world: World3D = viewport.find_world_3d() if viewport != null else null
	if camera != null:
		result["environment"] = camera.environment
		result["attributes"] = camera.attributes
		result["attributes_host"] = camera
		result["attributes_property"] = &"attributes"
	elif world_env != null:
		result["environment"] = world_env.environment
		result["attributes"] = world_env.camera_attributes
		result["attributes_host"] = world_env
		result["attributes_property"] = &"camera_attributes"
	# Fall back to the world for whatever the closer sources did not provide.
	if world != null:
		if result["environment"] == null:
			result["environment"] = world.environment
		if result["attributes"] == null and result["attributes_host"] == null:
			result["attributes"] = world.camera_attributes
			result["attributes_host"] = world
			result["attributes_property"] = &"camera_attributes"
	return result


static func _first_world_environment(start: Node) -> WorldEnvironment:
	var root := start.get_tree().root
	for node in root.find_children("*", "WorldEnvironment", true, false):
		if node is WorldEnvironment and (node as WorldEnvironment).environment != null:
			return node
	return null
