@icon("res://addons/juice/icons/floating_text.svg")
class_name JuiceFloatingText
extends Node
## Animates one floating text: the behaviour that a [JuiceFloatingTextSpawner] puts on
## each pooled label.
##
## It is a child of the node that shows the text (a [Label], a [Label3D], or the root of a
## custom scene) and moves, scales, fades and tints that parent over its lifetime. When
## the lifetime is over the parent is hidden and [signal finished] is emitted, which is how
## the spawner takes the instance back into its pool.
##
## You normally never create one yourself. To use it on your own label, add it as a child,
## fill a [JuiceFloatingText.Params] and call [method start].

## Emitted when the lifetime ended and the text was hidden.
signal finished(text_node: JuiceFloatingText)

## How the text is rotated while it floats. Only 2D nodes and controls rotate.
enum Alignment { FIXED, MATCH_INITIAL_DIRECTION, MATCH_MOVEMENT_DIRECTION }


## Everything one floating text needs to know. The spawner rolls the random values and
## fills one of these per spawn.
class Params extends RefCounted:
	## The text to show.
	var text: String = ""
	## Seconds the text lives.
	var lifetime: float = 1.0
	## True for a Node3D parent, false for a CanvasItem parent.
	var is_3d: bool = false
	## World position where the text starts (x and y only in 2D).
	var origin: Vector3 = Vector3.ZERO
	## The direction the text floats in. Its y movement goes along it.
	var direction: Vector3 = Vector3.UP
	## Pixels per unit of movement, for 2D.
	var pixels_per_unit: float = 64.0
	## Whether the text moves at all.
	var animate_movement: bool = true
	## Per axis (x, y, z): animated or not.
	var move_enabled: Array[bool] = [false, true, false]
	## Per axis: the easing. Null is linear.
	var move_tweens: Array[JuiceTween] = [null, null, null]
	## Per axis: the distance at the start of the lifetime.
	var move_from: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])
	## Per axis: the distance at the end of the lifetime.
	var move_to: PackedFloat32Array = PackedFloat32Array([0.0, 1.5, 0.0])
	## Alignment of the text, 2D only.
	var alignment: Alignment = Alignment.FIXED
	## Rotation in degrees for FIXED alignment, 2D only.
	var fixed_rotation_degrees: float = 0.0
	## Multiplies the size of the text on top of everything else.
	var size_scale: float = 1.0
	## Animates the scale.
	var animate_scale: bool = true
	## Easing of the scale. Null is linear.
	var scale_tween: JuiceTween
	## Scale at curve value 0.
	var scale_from: float = 0.0
	## Scale at curve value 1.
	var scale_to: float = 1.0
	## Animates the opacity.
	var animate_opacity: bool = true
	## Easing of the opacity. Null is linear.
	var opacity_tween: JuiceTween
	## Opacity at curve value 0.
	var opacity_from: float = 0.0
	## Opacity at curve value 1.
	var opacity_to: float = 1.0
	## The color the text has when there is no gradient.
	var tint: Color = Color.WHITE
	## A color over the lifetime. Null leaves [member tint] alone.
	var gradient: Gradient


var _params: Params
var _root: Node
var _elapsed := 0.0
var _active := false
var _unscaled := false
var _last_usec := 0
var _base_scale := Vector3.ONE
var _base_scale_known := false
var _attach: Node
var _attach_origin := Vector3.ZERO
var _attach_delta := Vector3.ZERO
var _last_position := Vector3.ZERO
var _movement_angle := 0.0
var _has_movement_angle := false


func _ready() -> void:
	set_process(false)


func _process(delta: float) -> void:
	var step := delta
	if _unscaled:
		var now := Time.get_ticks_usec()
		step = float(now - _last_usec) * 0.000001
		_last_usec = now
	advance(step)


## Starts a floating text on the parent node. [param attach_to] makes it follow that node.
## [param unscaled] ignores [member Engine.time_scale].
func start(params: Params, attach_to: Node = null, unscaled: bool = false) -> void:
	_root = get_parent()
	if _root == null:
		return
	_params = params
	_elapsed = 0.0
	_unscaled = unscaled
	_last_usec = Time.get_ticks_usec()
	_attach = attach_to
	_attach_delta = Vector3.ZERO
	_attach_origin = Juice.node_position(attach_to) if attach_to != null else Vector3.ZERO
	_has_movement_angle = false
	_movement_angle = 0.0
	_last_position = params.origin
	if _root is CanvasItem:
		(_root as CanvasItem).top_level = true
	elif _root is Node3D:
		(_root as Node3D).top_level = true
	# Visible first: a hidden control does not compute its minimum size.
	_set_visible(true)
	_set_text(params.text)
	_remember_base_scale()
	_active = true
	_update(0.0)
	set_process(true)


## Moves the animation forward by [param step] seconds. [code]_process[/code] calls this;
## call it yourself to drive the text by hand.
func advance(step: float) -> void:
	if not _active:
		return
	_elapsed += step
	var done := _elapsed >= _params.lifetime
	_update(1.0 if done else _elapsed / maxf(_params.lifetime, 0.0001))
	if done:
		deactivate()
		finished.emit(self)


## True while the text is floating.
func is_active() -> bool:
	return _active


## Hides the text and stops animating it, without emitting [signal finished].
func deactivate() -> void:
	_active = false
	set_process(false)
	_set_visible(false)


# --- Internals -------------------------------------------------------------

func _update(progress: float) -> void:
	if _root == null or _params == null:
		return
	var position := _params.origin
	if _attach != null:
		if is_instance_valid(_attach):
			_attach_delta = Juice.node_position(_attach) - _attach_origin
		position += _attach_delta
	if _params.animate_movement:
		position += _movement_offset(progress)
	_apply_position(position)
	_apply_scale(progress)
	_apply_color(progress)
	_apply_rotation(position)
	_last_position = position


func _movement_offset(progress: float) -> Vector3:
	var local := Vector3.ZERO
	for axis in 3:
		if not _params.move_enabled[axis]:
			continue
		var eased := JuiceTween.sample(_params.move_tweens[axis], progress)
		local[axis] = lerpf(_params.move_from[axis], _params.move_to[axis], eased)
	var direction := _params.direction
	if direction.length_squared() < 0.000001:
		direction = Vector3.UP
	direction = direction.normalized()
	if _params.is_3d:
		var reference := Vector3.FORWARD if absf(direction.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT
		var side := direction.cross(reference).normalized()
		var depth := side.cross(direction)
		return side * local.x + direction * local.y + depth * local.z
	var forward := Vector2(direction.x, direction.y).normalized()
	var side_2d := Vector2(-forward.y, forward.x)
	var offset_2d := (side_2d * local.x + forward * local.y) * _params.pixels_per_unit
	return Vector3(offset_2d.x, offset_2d.y, 0.0)


func _apply_position(position: Vector3) -> void:
	if _root is Node3D:
		(_root as Node3D).global_position = position
	elif _root is Control:
		# Scale and rotation happen around the pivot, so the pivot (the center of the text)
		# is what must sit on the position. The control is top level, so position is global.
		var control := _root as Control
		control.position = Vector2(position.x, position.y) - control.pivot_offset
	elif _root is Node2D:
		(_root as Node2D).global_position = Vector2(position.x, position.y)


func _apply_scale(progress: float) -> void:
	if not _params.animate_scale:
		_apply_base_size()
		return
	var curve_value := JuiceTween.sample(_params.scale_tween, progress)
	var factor := maxf(lerpf(_params.scale_from, _params.scale_to, curve_value) * _params.size_scale, 0.0001)
	if _root is Node3D:
		(_root as Node3D).scale = _base_scale * factor
	elif _root is Control:
		(_root as Control).scale = Vector2(_base_scale.x, _base_scale.y) * factor
	elif _root is Node2D:
		(_root as Node2D).scale = Vector2(_base_scale.x, _base_scale.y) * factor


func _apply_color(progress: float) -> void:
	if not "modulate" in _root:
		return
	var color := _params.tint
	if _params.gradient != null:
		color = _params.gradient.sample(progress) * _params.tint
	if _params.animate_opacity:
		color.a *= lerpf(_params.opacity_from, _params.opacity_to, JuiceTween.sample(_params.opacity_tween, progress))
	_root.set("modulate", color)


func _apply_rotation(position: Vector3) -> void:
	if _params.is_3d or not (_root is Node2D or _root is Control):
		return
	var angle := 0.0
	match _params.alignment:
		JuiceFloatingText.Alignment.FIXED:
			angle = deg_to_rad(_params.fixed_rotation_degrees)
		JuiceFloatingText.Alignment.MATCH_INITIAL_DIRECTION:
			angle = Vector2(_params.direction.x, _params.direction.y).angle() + PI * 0.5
		JuiceFloatingText.Alignment.MATCH_MOVEMENT_DIRECTION:
			var moved := Vector2(position.x - _last_position.x, position.y - _last_position.y)
			if moved.length() > 0.001:
				_movement_angle = moved.angle() + PI * 0.5
				_has_movement_angle = true
			angle = _movement_angle if _has_movement_angle else Vector2(_params.direction.x, _params.direction.y).angle() + PI * 0.5
	_root.set("rotation", angle)


func _set_text(text: String) -> void:
	if _root.has_method("set_floating_text"):
		_root.call("set_floating_text", text)
	elif "text" in _root:
		_root.set("text", text)
	if _root is Control:
		# A Control scales and rotates around its center, so it needs its real size.
		var control := _root as Control
		control.size = control.get_combined_minimum_size()
		control.pivot_offset = control.size * 0.5


# The scale the parent has the first time it is used is its normal size. Pooled parents
# are scaled by the animation, so later starts must not read that value again.
func _remember_base_scale() -> void:
	if _base_scale_known:
		return
	_base_scale_known = true
	if _root is Node3D:
		_base_scale = (_root as Node3D).scale
	elif _root is Node2D:
		var scale_2d := (_root as Node2D).scale
		_base_scale = Vector3(scale_2d.x, scale_2d.y, 1.0)
	elif _root is Control:
		var scale_ui := (_root as Control).scale
		_base_scale = Vector3(scale_ui.x, scale_ui.y, 1.0)


func _apply_base_size() -> void:
	var factor := maxf(_params.size_scale, 0.0001)
	if _root is Node3D:
		(_root as Node3D).scale = _base_scale * factor
	elif _root is Node2D or _root is Control:
		_root.set("scale", Vector2(_base_scale.x, _base_scale.y) * factor)


func _set_visible(shown: bool) -> void:
	if _root is CanvasItem:
		(_root as CanvasItem).visible = shown
	elif _root is Node3D:
		(_root as Node3D).visible = shown
