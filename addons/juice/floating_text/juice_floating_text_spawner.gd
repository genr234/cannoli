@tool
@icon("res://addons/juice/icons/floating_text.svg")
class_name JuiceFloatingTextSpawner
extends Node
## Spawns floating texts such as damage numbers, pickups or combo counters.
##
## Texts are pooled. By default each one is a [Label] (2D and UI) or a billboarded
## [Label3D] (3D), or you can set a [PackedScene] whose root is a CanvasItem (2D) or a
## Node3D (3D). A custom scene may have a [code]set_floating_text(text)[/code] method; if it
## does not, the [code]text[/code] property is used.
##
## The spawner can sit anywhere in the scene: texts use world positions and do not inherit
## the transform of their parent. Distances are in units. In 2D they are multiplied by
## [member pixels_per_unit], and y points up in offsets and movement like it does in 3D.
##
## It listens on the Juice bus for the event [code]juice_floating_text[/code] (see
## [constant EVENT]), sent by [JuiceShowText]. Keys of the payload, all optional:
## [code]text[/code] or [code]value[/code], [code]position[/code] (Vector3 or Vector2),
## [code]direction[/code] (Vector3), [code]intensity[/code] (float), [code]lifetime[/code]
## (float, 0 or less keeps the spawner's), [code]color[/code] (Color), [code]gradient[/code]
## (Gradient), [code]size[/code] (float, multiplies the size) and [code]attach[/code]
## (Node to follow). The standard [code]timescale_mode[/code] key picks unscaled time.
##
## Movement happens in the frame of the spawn direction: the y movement goes along the
## direction, x goes to its side, z is depth (3D only). With [member spread_degrees] the
## direction is turned randomly for each text.

## Emitted when a text starts floating.
signal spawned(text_node: Node, text: String)

## The bus event this node listens to.
const EVENT := &"juice_floating_text"

## Whether texts live on the canvas (2D nodes and UI) or in the 3D world.
enum Dimension { CANVAS_2D, SPATIAL_3D }

@export_group("General")
## 2D and UI, or 3D.
@export var dimension: Dimension = Dimension.CANVAS_2D:
	set(value):
		dimension = value
		notify_property_list_changed()
## Turn this off to stop spawning.
@export var enabled: bool = true
## Uses time that ignores [member Engine.time_scale] for every text.
@export var use_unscaled_time: bool = false
## Pixels in one unit of movement and offset, for 2D.
@export_range(1.0, 1000.0, 1.0, "or_greater") var pixels_per_unit: float = 64.0
## The z index of 2D texts, so they draw over the game.
@export var canvas_z_index: int = 100

@export_group("Channel")
## Reacts to texts sent on a channel.
@export var listen_to_channel: bool = true
## Reacts to every channel.
@export var any_channel: bool = false
## The integer channel to listen on.
@export var channel: int = 0
## A channel resource. When set it replaces [member channel].
@export var channel_resource: JuiceChannel

@export_group("Pool")
## A scene to use instead of the default label. Its root must be a CanvasItem in 2D or a
## Node3D in 3D.
@export var scene: PackedScene
## How many texts are created ahead of time.
@export_range(0, 200, 1, "or_greater") var pool_size: int = 8
## Creates more texts when all are floating. When off, the oldest one is reused.
@export var pool_can_expand: bool = true

@export_group("Default Label")
## The font of the default label. Null uses the theme font.
@export var font: Font
## The font size of the default label.
@export_range(1, 256, 1, "or_greater") var font_size: int = 24
## The outline thickness of the default label. 0 has none.
@export_range(0, 32, 1, "or_greater") var outline_size: int = 4
## The color of the outline.
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.85)
## The size of one pixel of the default label in the world, for 3D.
@export_range(0.0001, 1.0, 0.0001, "or_greater") var pixel_size: float = 0.01
## Makes the default 3D label face the camera.
@export var billboard: bool = true
## Draws the default 3D label over everything else.
@export var always_on_top: bool = false
## The color texts start with. Lives in the modulate of the label.
@export var text_color: Color = Color.WHITE

@export_group("Spawn")
## Seconds a text lives, as a random range.
@export var lifetime: Vector2 = Vector2(1.0, 1.0)
## The lowest random offset from the spawn position, in units.
@export var spawn_offset_min: Vector3 = Vector3.ZERO
## The highest random offset from the spawn position, in units.
@export var spawn_offset_max: Vector3 = Vector3.ZERO
## The direction texts float in, for 2D. The default is up.
@export var direction_2d: Vector2 = Vector2.UP
## The direction texts float in, for 3D.
@export var direction_3d: Vector3 = Vector3.UP
## Turns the direction randomly by up to this many degrees on each side.
@export_range(0.0, 180.0, 0.1, "suffix:°") var spread_degrees: float = 0.0

@export_group("Movement")
## Moves the texts.
@export var animate_movement: bool = true
## Moves sideways.
@export var animate_x: bool = false
## Sideways distance at the start of the life, as a random range.
@export var x_from: Vector2 = Vector2.ZERO
## Sideways distance at the end of the life, as a random range.
@export var x_to: Vector2 = Vector2.ONE
## Easing of the sideways movement. Null is linear.
@export var x_tween: JuiceTween
## Moves along the direction.
@export var animate_y: bool = true
## Distance along the direction at the start of the life, as a random range.
@export var y_from: Vector2 = Vector2.ZERO
## Distance along the direction at the end of the life, as a random range.
@export var y_to: Vector2 = Vector2(1.5, 1.5)
## Easing of the movement along the direction. Null is linear.
@export var y_tween: JuiceTween = JuiceTween.make_ease_out()
## Moves in depth, for 3D.
@export var animate_z: bool = false
## Depth distance at the start of the life, as a random range.
@export var z_from: Vector2 = Vector2.ZERO
## Depth distance at the end of the life, as a random range.
@export var z_to: Vector2 = Vector2.ONE
## Easing of the depth movement. Null is linear.
@export var z_tween: JuiceTween

@export_group("Alignment")
## How 2D texts are rotated. 3D texts are not rotated; use the billboard.
@export var align_mode: JuiceFloatingText.Alignment = JuiceFloatingText.Alignment.FIXED
## The rotation for FIXED alignment, in degrees.
@export_range(-360.0, 360.0, 0.1, "suffix:°") var fixed_rotation_degrees: float = 0.0

@export_group("Scale")
## Animates the scale over the life.
@export var animate_scale: bool = true
## Scale at curve value 0, as a random range.
@export var scale_from: Vector2 = Vector2.ZERO
## Scale at curve value 1, as a random range.
@export var scale_to: Vector2 = Vector2.ONE
## The scale over the life. Null is linear.
@export var scale_tween: JuiceTween = _make_hump(0.15, 0.85)

@export_group("Color")
## Tints the text with a gradient over its life.
@export var animate_color: bool = false
## The color over the life.
@export var color_gradient: Gradient = _make_gradient()

@export_group("Opacity")
## Fades the text over the life.
@export var animate_opacity: bool = true
## Opacity at curve value 0, as a random range.
@export var opacity_from: Vector2 = Vector2.ZERO
## Opacity at curve value 1, as a random range.
@export var opacity_to: Vector2 = Vector2.ONE
## The opacity over the life. Null is linear.
@export var opacity_tween: JuiceTween = _make_hump(0.2, 0.8)

@export_group("Intensity")
## Intensity multiplies the lifetime.
@export var intensity_affects_lifetime: bool = false
## The extra factor for the lifetime.
@export var intensity_lifetime_multiplier: float = 1.0
## Intensity multiplies the movement distance.
@export var intensity_affects_movement: bool = false
## The extra factor for the movement.
@export var intensity_movement_multiplier: float = 1.0
## Intensity multiplies the size.
@export var intensity_affects_scale: bool = false
## The extra factor for the size.
@export var intensity_scale_multiplier: float = 1.0

var _free: Array[JuiceFloatingText] = []
var _busy: Array[JuiceFloatingText] = []
var _prewarmed := false


static func _make_hump(rise: float, fall: float) -> JuiceTween:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(rise, 1.0))
	curve.add_point(Vector2(fall, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	return JuiceTween.make_curve(curve)


static func _make_gradient() -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 0.45, 0.35))
	return gradient


func _validate_property(property: Dictionary) -> void:
	var prop_name: String = property.name
	var is_3d := dimension == Dimension.SPATIAL_3D
	if prop_name in ["pixels_per_unit", "canvas_z_index", "direction_2d", "align_mode", "fixed_rotation_degrees"] and is_3d:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["pixel_size", "billboard", "always_on_top", "direction_3d", "animate_z", "z_from", "z_to", "z_tween"] and not is_3d:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _enter_tree() -> void:
	if Engine.is_editor_hint() or not listen_to_channel:
		return
	var listened: Variant = null if any_channel else _get_channel()
	Juice.listen(EVENT, listened, _on_text_event)


func _exit_tree() -> void:
	Juice.unlisten(EVENT, _on_text_event)


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_prewarm()


# --- Public API ------------------------------------------------------------

## Spawns a floating text. [param value] is shown as text (numbers lose trailing zeros).
## [param position] is a Vector2, Vector3 or a node, and null means the position of this
## node when it is a Node2D or Node3D. [param options] takes the same keys as the bus
## payload: direction, intensity, lifetime, color, gradient, size, attach, unscaled.
## Returns the node that shows the text, or null when nothing was spawned.
func spawn(value: Variant, position: Variant = null, options: Dictionary = {}) -> Node:
	if not enabled or Engine.is_editor_hint() or not is_inside_tree():
		return null
	var animator := _take()
	if animator == null:
		return null
	var is_3d := dimension == Dimension.SPATIAL_3D
	var intensity: float = options.get("intensity", 1.0)
	var origin := Juice.to_vector3(position, Juice.node_position(self))
	if is_3d:
		origin += _random_vector(spawn_offset_min, spawn_offset_max)
	else:
		var offset := _random_vector(spawn_offset_min, spawn_offset_max) * pixels_per_unit
		origin += Vector3(offset.x, -offset.y, 0.0)

	var lifetime_factor := intensity * intensity_lifetime_multiplier if intensity_affects_lifetime else 1.0
	var movement_factor := intensity * intensity_movement_multiplier if intensity_affects_movement else 1.0
	var scale_factor := intensity * intensity_scale_multiplier if intensity_affects_scale else 1.0

	var params := JuiceFloatingText.Params.new()
	params.text = _to_text(value)
	params.is_3d = is_3d
	params.origin = origin
	params.pixels_per_unit = pixels_per_unit
	params.lifetime = randf_range(lifetime.x, lifetime.y) * lifetime_factor
	var forced_lifetime: float = options.get("lifetime", 0.0)
	if forced_lifetime > 0.0:
		params.lifetime = forced_lifetime
	params.lifetime = maxf(params.lifetime, 0.01)
	params.direction = _pick_direction(options.get("direction", Vector3.ZERO))
	params.animate_movement = animate_movement
	params.move_enabled = [animate_x, animate_y, animate_z and is_3d]
	params.move_tweens = [x_tween, y_tween, z_tween]
	params.move_from = PackedFloat32Array([_roll(x_from), _roll(y_from), _roll(z_from)])
	params.move_to = PackedFloat32Array([_roll(x_to) * movement_factor, _roll(y_to) * movement_factor, _roll(z_to) * movement_factor])
	params.alignment = align_mode
	params.fixed_rotation_degrees = fixed_rotation_degrees
	params.size_scale = float(options.get("size", 1.0))
	params.animate_scale = animate_scale
	params.scale_tween = scale_tween
	params.scale_from = _roll(scale_from)
	params.scale_to = _roll(scale_to) * scale_factor
	params.animate_opacity = animate_opacity
	params.opacity_tween = opacity_tween
	params.opacity_from = _roll(opacity_from)
	params.opacity_to = _roll(opacity_to)
	params.tint = options.get("color", text_color)
	var forced_gradient: Gradient = options.get("gradient", null)
	if forced_gradient != null:
		params.gradient = forced_gradient
	elif animate_color:
		params.gradient = color_gradient

	var unscaled := use_unscaled_time or bool(options.get("unscaled", false))
	var attach: Node = options.get("attach", null)
	animator.start(params, attach, unscaled)
	spawned.emit(animator.get_parent(), params.text)
	return animator.get_parent()


## How many texts are floating right now.
func get_active_count() -> int:
	return _busy.size()


## Hides every floating text at once.
func clear() -> void:
	for animator in _busy.duplicate():
		animator.deactivate()
		_release(animator)


# --- Bus -------------------------------------------------------------------

func _on_text_event(payload: Dictionary) -> void:
	var content: Variant = payload.get("text", payload.get("value", ""))
	var unscaled: bool = payload.get("timescale_mode", Juice.TimeMode.SCALED) == Juice.TimeMode.UNSCALED
	var options := payload.duplicate()
	options["unscaled"] = unscaled
	spawn(content, payload.get("position", null), options)


func _get_channel() -> Variant:
	if channel_resource != null:
		return channel_resource
	return channel


# --- Pool ------------------------------------------------------------------

func _prewarm() -> void:
	if _prewarmed:
		return
	_prewarmed = true
	for i in pool_size:
		var animator := _create()
		if animator != null:
			_free.append(animator)


func _take() -> JuiceFloatingText:
	_prewarm()
	while not _free.is_empty():
		var animator: JuiceFloatingText = _free.pop_back()
		if is_instance_valid(animator):
			_busy.append(animator)
			return animator
	if pool_can_expand or _busy.is_empty():
		var created := _create()
		if created != null:
			_busy.append(created)
		return created
	# No room to grow: take the text that has been floating the longest.
	var oldest: JuiceFloatingText = _busy.pop_front()
	_busy.append(oldest)
	return oldest


func _release(animator: JuiceFloatingText) -> void:
	_busy.erase(animator)
	if is_instance_valid(animator) and not _free.has(animator):
		_free.append(animator)


func _on_finished(animator: JuiceFloatingText) -> void:
	_release(animator)


func _create() -> JuiceFloatingText:
	var root: Node = _make_root()
	if root == null:
		return null
	add_child(root)
	_hide(root)
	var animator := JuiceFloatingText.new()
	animator.name = "FloatingText"
	root.add_child(animator)
	animator.finished.connect(_on_finished)
	return animator


func _make_root() -> Node:
	var is_3d := dimension == Dimension.SPATIAL_3D
	if scene != null:
		var instance := scene.instantiate()
		if (is_3d and instance is Node3D) or (not is_3d and instance is CanvasItem):
			if instance is CanvasItem:
				(instance as CanvasItem).z_index = canvas_z_index
			return instance
		push_warning("JuiceFloatingTextSpawner '%s': the scene root must be a %s." % [name, "Node3D" if is_3d else "CanvasItem"])
		instance.queue_free()
		return null
	if is_3d:
		return _make_label_3d()
	return _make_label()


func _make_label() -> Label:
	var label := Label.new()
	label.name = "Label"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = canvas_z_index
	label.add_theme_font_size_override("font_size", font_size)
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_constant_override("outline_size", outline_size)
	label.add_theme_color_override("font_outline_color", outline_color)
	return label


func _make_label_3d() -> Label3D:
	var label := Label3D.new()
	label.name = "Label3D"
	label.font_size = font_size
	label.outline_size = outline_size
	label.outline_modulate = outline_color
	label.pixel_size = pixel_size
	label.no_depth_test = always_on_top
	label.shaded = false
	if font != null:
		label.font = font
	if billboard:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return label


func _hide(root: Node) -> void:
	if root is CanvasItem:
		(root as CanvasItem).visible = false
	elif root is Node3D:
		(root as Node3D).visible = false


# --- Helpers ---------------------------------------------------------------

func _roll(range_value: Vector2) -> float:
	return randf_range(range_value.x, range_value.y)


func _random_vector(low: Vector3, high: Vector3) -> Vector3:
	return Vector3(randf_range(low.x, high.x), randf_range(low.y, high.y), randf_range(low.z, high.z))


## Turns a number into text without trailing zeros: 12.0 becomes "12" and 0.5 stays "0.5".
static func number_to_text(number: float) -> String:
	if is_equal_approx(number, roundf(number)):
		return str(roundi(number))
	return ("%.3f" % number).rstrip("0").rstrip(".")


func _to_text(value: Variant) -> String:
	match typeof(value):
		TYPE_FLOAT:
			return number_to_text(value)
		TYPE_STRING, TYPE_STRING_NAME:
			return String(value)
	return str(value)


# A payload direction replaces the spawner's own, then the spread turns it.
func _pick_direction(requested: Vector3) -> Vector3:
	var is_3d := dimension == Dimension.SPATIAL_3D
	var base := direction_3d if is_3d else Vector3(direction_2d.x, direction_2d.y, 0.0)
	if requested.length_squared() > 0.000001:
		base = requested
	if base.length_squared() < 0.000001:
		base = Vector3.UP if is_3d else Vector3(0.0, -1.0, 0.0)
	base = base.normalized()
	if spread_degrees <= 0.0:
		return base
	var spread := deg_to_rad(spread_degrees)
	if not is_3d:
		var turned := Vector2(base.x, base.y).rotated(randf_range(-spread, spread))
		return Vector3(turned.x, turned.y, 0.0)
	# 3D: tilt away from the direction by up to the spread, around a random axis.
	var reference := Vector3.RIGHT if absf(base.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var axis := base.cross(reference).normalized().rotated(base, randf() * TAU)
	return base.rotated(axis, randf_range(0.0, spread))
