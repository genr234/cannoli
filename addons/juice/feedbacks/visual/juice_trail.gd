@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceTrail
extends JuiceFeedback
## Drives a trail or a line: width and color of a [Line2D], a recorded follow trail, or a
## particle trail that emits only while the feedback runs.
##
## LINE2D animates the width and color of a [Line2D] and can clear its points. With
## [member record_points] on, the line also records the position of another node as a trail and
## drops old points after [member trail_time]; turn on Top Level on the Line2D so the trail
## stays where it was drawn. PARTICLES switches a particle node's emitting on for the play.

## What the feedback drives.
enum Method {
	## A [Line2D].
	LINE2D,
	## A [GPUParticles2D], [GPUParticles3D], [CPUParticles2D] or [CPUParticles3D] used as a trail.
	PARTICLES,
}

@export_group("Trail")
## What to drive.
@export var method: Method = Method.LINE2D:
	set(value):
		method = value
		notify_property_list_changed()
## Seconds one play takes.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.5
## The curve of the animation. Null is a straight line.
@export var tween: JuiceTween
@export_group("Line Width")
## Changes the line width.
@export var animate_width: bool = true
## The width at curve position 0.
@export_range(0.0, 100.0, 0.1, "or_greater") var from_width: float = 0.0
## The width at curve position 1.
@export_range(0.0, 100.0, 0.1, "or_greater") var to_width: float = 8.0
@export_group("Line Color")
## Changes the line color.
@export var animate_color: bool = false
## The color at curve position 0.
@export var from_color: Color = Color.WHITE
## The color at curve position 1.
@export var to_color: Color = Color(1.0, 1.0, 1.0, 0.0)
## Reads the color from a gradient instead of blending the two colors.
@export var use_gradient: bool = false
## The gradient sampled over the play.
@export var gradient: Gradient
@export_group("Line Points")
## Removes every point of the line when the play starts.
@export var clear_on_play: bool = false
## Records the position of [member follow] as a trail while the feedback runs.
@export var record_points: bool = false
## The node whose position is recorded. Empty uses the parent of the Line2D.
@export var follow: NodePath = NodePath()
## Seconds a recorded point lives. 0 keeps points until [member max_points] is reached.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var trail_time: float = 0.5
## The most points the trail holds.
@export_range(2, 500, 1, "or_greater") var max_points: int = 40
## Seconds that must pass before another point is recorded.
@export_range(0.0, 1.0, 0.001, "or_greater", "suffix:s") var point_interval: float = 0.016

var _initial_width := 0.0
var _initial_color := Color.WHITE
var _initial_points := PackedVector2Array()
var _initial_emitting := false
var _captured := false
var _stamps: PackedFloat64Array = PackedFloat64Array()
var _since_point := 0.0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	var line_only := [
		"Line Width", "animate_width", "from_width", "to_width",
		"Line Color", "animate_color", "from_color", "to_color", "use_gradient", "gradient",
		"Line Points", "clear_on_play", "record_points", "follow", "trail_time", "max_points", "point_interval",
	]
	if prop_name in line_only and method != Method.LINE2D:
		if property.usage & PROPERTY_USAGE_GROUP:
			property.usage = PROPERTY_USAGE_NONE
		else:
			property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["tween"] and method != Method.LINE2D:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _on_initialize() -> void:
	_capture()


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if node == null:
		return
	if not _captured:
		_capture()
	_since_point = 0.0
	if method == Method.PARTICLES:
		_set_emitting(node, true)
		return
	if node is Line2D:
		if clear_on_play and not is_retrigger():
			(node as Line2D).clear_points()
			_stamps.clear()
		if duration <= 0.0:
			_apply(node as Line2D, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target()
	if method == Method.LINE2D and node is Line2D:
		_apply(node as Line2D, progress)


func _on_tick() -> void:
	var node := get_target()
	if method == Method.LINE2D and record_points and node is Line2D:
		_record(node as Line2D)


func _on_finished() -> void:
	var node := get_target()
	if method == Method.PARTICLES and node != null:
		_set_emitting(node, false)


func _on_stop() -> void:
	var node := get_target()
	if method == Method.PARTICLES and node != null and _captured:
		_set_emitting(node, false)


func _on_restore() -> void:
	var node := get_target()
	if node == null or not _captured:
		return
	if method == Method.PARTICLES:
		_set_emitting(node, _initial_emitting)
	elif node is Line2D:
		var line := node as Line2D
		line.width = _initial_width
		line.default_color = _initial_color
		line.points = _initial_points
		_stamps.clear()
	_captured = false


func _capture() -> void:
	var node := get_target()
	if node == null:
		return
	_captured = true
	if node is Line2D:
		var line := node as Line2D
		_initial_width = line.width
		_initial_color = line.default_color
		_initial_points = line.points
	elif "emitting" in node:
		_initial_emitting = node.get("emitting")


func _set_emitting(node: Node, value: bool) -> void:
	if "emitting" in node:
		node.set("emitting", value)


func _apply(line: Line2D, progress: float) -> void:
	var shaped := JuiceTween.sample(tween, progress)
	var intensity := get_intensity()
	if animate_width:
		line.width = lerpf(_initial_width, lerpf(from_width, to_width, shaped), intensity)
	if animate_color:
		var color := gradient.sample(clampf(shaped, 0.0, 1.0)) if use_gradient and gradient != null else from_color.lerp(to_color, shaped)
		line.default_color = _initial_color.lerp(color, clampf(intensity, 0.0, 1.0))


func _record(line: Line2D) -> void:
	var now := Juice.unscaled_time()
	# Drop points that outlived the trail.
	if trail_time > 0.0:
		while _stamps.size() > 0 and now - _stamps[0] > trail_time and line.get_point_count() > 0:
			line.remove_point(0)
			_stamps.remove_at(0)
	_since_point += get_delta()
	if _since_point < point_interval:
		return
	_since_point = 0.0
	var followed := resolve(follow) if not follow.is_empty() else (line.get_parent() as Node)
	if followed == null:
		return
	var world := Juice.node_position(followed)
	line.add_point(line.to_local(Vector2(world.x, world.y)))
	_stamps.append(now)
	while line.get_point_count() > max_points:
		line.remove_point(0)
		if _stamps.size() > 0:
			_stamps.remove_at(0)
