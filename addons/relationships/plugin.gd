@tool
extends EditorPlugin

const InspectorPlugin := preload("editor/inspector_plugin.gd")
const DebuggerPlugin := preload("editor/debugger_plugin.gd")
const RelationshipMatrix := preload("editor/relationship_matrix.gd")
const FOV_COLORS: Array[Color] = [Color(1, 0.85, 0.3, 0.9), Color(1, 0.6, 0.3, 0.7), Color(1, 0.4, 0.4, 0.5)]
const ARC_SEGMENTS := 24

var _inspector_plugin: InspectorPlugin
var _debugger_plugin: DebuggerPlugin
var _matrix: RelationshipMatrix
var _matrix_button: Button
var _vision: CanSeeAdvanced


func _enter_tree() -> void:
	_inspector_plugin = InspectorPlugin.new()
	add_inspector_plugin(_inspector_plugin)
	_debugger_plugin = DebuggerPlugin.new()
	add_debugger_plugin(_debugger_plugin)
	_matrix = RelationshipMatrix.new()
	_matrix_button = add_control_to_bottom_panel(_matrix, "Relationships")
	set_process(false)


func _exit_tree() -> void:
	remove_inspector_plugin(_inspector_plugin)
	remove_debugger_plugin(_debugger_plugin)
	remove_control_from_bottom_panel(_matrix)
	_matrix.queue_free()
	_inspector_plugin = null
	_debugger_plugin = null


func _handles(object: Object) -> bool:
	return object is FactionDatabase or object is CanSeeAdvanced


func _edit(object: Object) -> void:
	if object is FactionDatabase:
		_matrix.edit(object)
	_vision = object as CanSeeAdvanced
	set_process(_vision != null)
	update_overlays()


func _make_visible(visible: bool) -> void:
	if visible and EditorInterface.get_inspector().get_edited_object() is FactionDatabase:
		make_bottom_panel_item_visible(_matrix)
	if not visible:
		_vision = null
		set_process(false)
		update_overlays()


# Keep the field-of-view overlay in sync while a CanSeeAdvanced is selected.
func _process(_delta: float) -> void:
	update_overlays()


func _forward_3d_draw_over_viewport(overlay: Control) -> void:
	var eyes := _vision_eyes()
	if not eyes is Node3D:
		return
	var camera := EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var origin: Vector3 = eyes.global_position
	var forward: Vector3 = -(eyes as Node3D).global_basis.z
	forward.y = 0.0
	if forward.is_zero_approx():
		return
	forward = forward.normalized()
	for i in _vision.fields_of_view.size():
		var fov := _vision.fields_of_view[i]
		if fov == null:
			continue
		var color := FOV_COLORS[i % FOV_COLORS.size()]
		var half := deg_to_rad(minf(fov.horizontal_fov, 360.0) / 2.0)
		var points := PackedVector2Array()
		for step in ARC_SEGMENTS + 1:
			var angle := lerpf(-half, half, float(step) / ARC_SEGMENTS)
			var point := origin + forward.rotated(Vector3.UP, angle) * fov.max_distance
			if camera.is_position_behind(point):
				points.clear()
				break
			points.append(camera.unproject_position(point))
		if points.is_empty() or camera.is_position_behind(origin):
			continue
		var center := camera.unproject_position(origin)
		overlay.draw_polyline(points, color, 2.0, true)
		if fov.horizontal_fov < 360.0:
			overlay.draw_line(center, points[0], color, 1.5, true)
			overlay.draw_line(center, points[points.size() - 1], color, 1.5, true)


func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	var eyes := _vision_eyes()
	if not eyes is Node2D:
		return
	var to_screen: Transform2D = eyes.get_viewport_transform() * (eyes as Node2D).global_transform
	for i in _vision.fields_of_view.size():
		var fov := _vision.fields_of_view[i]
		if fov == null:
			continue
		var color := FOV_COLORS[i % FOV_COLORS.size()]
		var half := deg_to_rad(minf(fov.vertical_fov, 360.0) / 2.0)
		var points := PackedVector2Array()
		for step in ARC_SEGMENTS + 1:
			points.append(to_screen * (Vector2.RIGHT.rotated(lerpf(-half, half, float(step) / ARC_SEGMENTS)) * fov.max_distance))
		var center := to_screen * Vector2.ZERO
		overlay.draw_polyline(points, color, 2.0, true)
		if fov.vertical_fov < 360.0:
			overlay.draw_line(center, points[0], color, 1.5, true)
			overlay.draw_line(center, points[points.size() - 1], color, 1.5, true)


func _vision_eyes() -> Node:
	if not is_instance_valid(_vision) or not _vision.is_inside_tree():
		return null
	var member := _vision.member if _vision.member != null else FactionMember.find_nearest(_vision)
	return member.get_eyes() if member != null else null
