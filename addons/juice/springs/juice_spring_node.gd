@tool
@icon("res://addons/juice/icons/spring.svg")
class_name JuiceSpringNode
extends Node
## Springs one property of a node, or the engine time scale.
##
## Point [member target_property] at any float, int, Vector2, Vector3, Vector4 or Color
## property, for example [code]Sprite2D:modulate[/code] or [code]../Camera3D:fov[/code]. The
## spring type follows the property. Then move it with [method move_to], [method bump] and
## friends, or let a [JuiceSpringFeedback] do it, directly or by channel.
##
## Presets cover the common cases: position, rotation and scale that pick the right
## property for 2D, 3D and UI nodes, a volume-preserving squash and stretch, and the
## engine time scale. They replace one component per property: anything else is just a
## property path (light energy, camera fov or zoom, audio pitch or volume, font size,
## progress value, shader parameters and so on).
##
## The node sleeps when the spring is at rest and wakes up on the next command.
## The spring writes absolute values, so something else that moves the same property at the
## same time will fight it. Call [method grab_current_value] after moving the node yourself.
##
## Listens on the Juice bus for the event [code]juice_spring[/code] (see [constant EVENT])
## and answers the keys documented on [method JuiceSpring.apply_command], plus
## [code]id[/code]: when it is not empty only springs with the same [member id] react.

## Emitted when the spring comes to rest on its target.
signal settled

## The bus event this node listens to.
const EVENT := &"juice_spring"

## What the spring drives.
enum Preset { PROPERTY, POSITION, ROTATION, SCALE, SQUASH_AND_STRETCH, TIME_SCALE }
## Position and rotation can be read and written in local or global space.
enum Space { LOCAL, GLOBAL }
## Which axis stretches and which ones squash, for SQUASH_AND_STRETCH.
enum SquashAxis { X_TO_YZ, X_TO_Y, X_TO_Z, Y_TO_XZ, Y_TO_X, Y_TO_Z, Z_TO_XZ, Z_TO_X, Z_TO_Y }

@export_group("Target")
## What this spring drives.
@export var preset: Preset = Preset.PROPERTY:
	set(value):
		preset = value
		notify_property_list_changed()
## The node and property to spring, as a node path with a property, for example
## [code]Sprite2D:scale[/code]. Without a node part the parent is used. Presets use the
## parent, or the node of this path when it has one.
@export var target_property: NodePath = NodePath("")
## Local or global space, for the POSITION and ROTATION presets.
@export var space: Space = Space.LOCAL
## The axis to stretch, for SQUASH_AND_STRETCH.
@export var squash_axis: SquashAxis = SquashAxis.Y_TO_XZ

@export_group("Spring")
## The spring settings. Each node uses its own copy at runtime.
@export var spring: JuiceSpring = JuiceSpring.new()
## Speed and distance under which the spring counts as at rest and the node goes to sleep.
@export_range(0.0001, 0.1, 0.0001, "or_greater") var rest_threshold: float = 0.001
## Uses time that ignores [member Engine.time_scale].
@export var time_mode: Juice.TimeMode = Juice.TimeMode.SCALED

@export_group("Channel")
## Reacts to spring feedbacks that broadcast on a channel.
@export var listen_to_channel: bool = true
## Reacts to every channel.
@export var any_channel: bool = false
## The integer channel to listen on.
@export var channel: int = 0
## A channel resource. When set it replaces [member channel].
@export var channel_resource: JuiceChannel
## Only commands that carry the same id (or no id) are accepted. Lets several springs share
## a channel.
@export var id: StringName = &""

@export_group("Randomness")
## The range used by [method move_to_random] when it gets no arguments.
@export var move_to_random_range: Vector2 = Vector2(-2.0, 2.0)
## The range used by [method bump_random] when it gets no arguments.
@export var bump_random_range: Vector2 = Vector2(20.0, 100.0)

var _spring: JuiceSpring
var _node: Node
var _property := NodePath("")
var _is_int := false
var _initial_scale := Vector3.ONE
var _awake := false
var _last_usec := 0
var _ready_done := false


func _validate_property(property: Dictionary) -> void:
	var prop_name: String = property.name
	if prop_name == "target_property" and preset == Preset.TIME_SCALE:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "space" and preset not in [Preset.POSITION, Preset.ROTATION]:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "squash_axis" and preset != Preset.SQUASH_AND_STRETCH:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _ready() -> void:
	set_process(false)
	if Engine.is_editor_hint():
		return
	initialize()


func _enter_tree() -> void:
	if Engine.is_editor_hint() or not listen_to_channel:
		return
	var listened: Variant = null if any_channel else _get_channel()
	Juice.listen(EVENT, listened, _on_spring_event)


func _exit_tree() -> void:
	Juice.unlisten(EVENT, _on_spring_event)


func _process(delta: float) -> void:
	var step := delta
	if time_mode == Juice.TimeMode.UNSCALED or preset == Preset.TIME_SCALE:
		var now := Time.get_ticks_usec()
		step = float(now - _last_usec) * 0.000001
		_last_usec = now
	_advance(minf(step, 0.25))


# --- Public API ------------------------------------------------------------

## Finds the target and reads its current value as the initial one. Called on ready; call it
## again after changing [member preset] or [member target_property] at runtime.
func initialize() -> bool:
	_ready_done = false
	_spring = (spring.duplicate() as JuiceSpring) if spring != null else JuiceSpring.new()
	_node = null
	_is_int = false
	if preset == Preset.TIME_SCALE:
		_spring.setup(Engine.time_scale)
	else:
		_node = _find_node()
		if _node == null:
			return false
		if not _resolve_property():
			return false
		var start: Variant = _read()
		if not _spring.setup(start):
			push_warning("JuiceSpringNode '%s': property '%s' cannot be sprung." % [name, _property])
			return false
	_configure_spring()
	_ready_done = true
	return true


## The runtime spring. Read its [member JuiceSpring.current], or change its settings.
func get_spring() -> JuiceSpring:
	return _spring


## The current value of the spring.
func get_value() -> Variant:
	return _spring.current if _spring != null else null


## True when the spring is at rest.
func is_settled() -> bool:
	return _spring == null or not _awake


## Moves the target to [param value].
func move_to(value: Variant) -> void:
	if _prepare():
		_spring.move_to(value)
		_wake()


## Adds [param amount] to the target.
func move_to_additive(amount: Variant) -> void:
	if _prepare():
		_spring.move_to_additive(amount)
		_wake()


## Subtracts [param amount] from the target.
func move_to_subtractive(amount: Variant) -> void:
	if _prepare():
		_spring.move_to_subtractive(amount)
		_wake()


## Picks a random target. Without arguments it uses [member move_to_random_range].
func move_to_random(min_value: Variant = null, max_value: Variant = null) -> void:
	if not _prepare():
		return
	_spring.move_to_random(move_to_random_range.x if min_value == null else min_value,
			move_to_random_range.y if max_value == null else max_value)
	_wake()


## Jumps to [param value] without any motion.
func move_to_instant(value: Variant) -> void:
	if _prepare():
		_spring.move_to_instant(value)
		_write()
		_wake()


## Kicks the spring with extra speed.
func bump(amount: Variant) -> void:
	if _prepare():
		_spring.bump(amount)
		_wake()


## Kicks the spring with a random speed. Without arguments it uses [member bump_random_range].
func bump_random(min_value: Variant = null, max_value: Variant = null) -> void:
	if not _prepare():
		return
	_spring.bump_random(bump_random_range.x if min_value == null else min_value,
			bump_random_range.y if max_value == null else max_value)
	_wake()


## Stops the motion where it is.
func stop() -> void:
	if _spring == null:
		return
	_grab_if_possible()
	_spring.stop()
	_sleep(false)


## Snaps to the target and rests.
func finish() -> void:
	if _spring == null:
		return
	_spring.finish()
	_write()
	_sleep(false)


## Goes back to the value found at startup.
func restore_initial() -> void:
	if _spring == null:
		return
	_spring.restore_initial()
	_write()
	_sleep(false)


## Makes the current value the one [method restore_initial] returns to.
func reset_initial() -> void:
	if _spring != null:
		_spring.set_current_as_initial()


## Reads the property again and rests there. Use it after moving the node yourself.
## For SQUASH_AND_STRETCH the current scale becomes the new resting scale.
func grab_current_value() -> void:
	if not _prepare():
		return
	if preset == Preset.SQUASH_AND_STRETCH:
		_initial_scale = _read_scale()
		_spring.setup(1.0)
	else:
		_awake = false
		_grab_if_possible()
		_spring.stop()
	_sleep(false)


## Runs a command dictionary, the same one the event bus delivers. See
## [method JuiceSpring.apply_command].
func apply_command(data: Dictionary) -> void:
	if not _prepare():
		return
	var command: int = data.get("command", JuiceSpring.Command.BUMP)
	if command == JuiceSpring.Command.STOP:
		stop()
		return
	if command == JuiceSpring.Command.FINISH:
		finish()
		return
	if command == JuiceSpring.Command.RESTORE:
		restore_initial()
		return
	_spring.apply_command(data)
	if command == JuiceSpring.Command.MOVE_TO_INSTANT:
		_write()
	_wake()


# --- Bus -------------------------------------------------------------------

func _on_spring_event(payload: Dictionary) -> void:
	var wanted: StringName = payload.get("id", &"")
	if wanted != &"" and wanted != id:
		return
	apply_command(payload)


func _get_channel() -> Variant:
	if channel_resource != null:
		return channel_resource
	return channel


# --- Internals -------------------------------------------------------------

func _prepare() -> bool:
	if _spring == null or not _ready_done:
		if not is_inside_tree() or Engine.is_editor_hint():
			return false
		initialize()
	if _spring == null or not _ready_done:
		return false
	if preset != Preset.TIME_SCALE and not is_instance_valid(_node):
		return false
	if not _awake:
		_grab_if_possible()
	return true


func _wake() -> void:
	if _awake:
		return
	_awake = true
	_last_usec = Time.get_ticks_usec()
	set_process(true)


func _sleep(notify: bool) -> void:
	_awake = false
	set_process(false)
	if notify:
		settled.emit()


func _advance(delta: float) -> void:
	if _spring == null:
		_sleep(false)
		return
	if preset != Preset.TIME_SCALE and not is_instance_valid(_node):
		_sleep(false)
		return
	_spring.update(delta)
	if _spring.is_settled(rest_threshold, rest_threshold):
		_spring.finish()
		_write()
		_sleep(true)
		return
	_write()


# While asleep the node may have been moved by someone else, so the spring starts from
# what is really there. Springs on the time scale are always read back too.
func _grab_if_possible() -> void:
	if _awake or _spring == null:
		return
	if preset == Preset.SQUASH_AND_STRETCH:
		return
	var value: Variant = _read()
	if JuiceSpring.value_type_of(value) == _spring.get_value_type():
		var was_initial: Variant = _spring.initial
		_spring.current = value
		_spring.target = value
		_spring.velocity = Vector4.ZERO
		_spring.initial = was_initial


func _configure_spring() -> void:
	if preset == Preset.SQUASH_AND_STRETCH:
		# A factor at or below zero would flip the node inside out.
		_spring.clamp_min = true
		_spring.clamp_min_value = Vector4(0.05, 0.05, 0.05, 0.05)
		_spring.clamp_min_initial = false
		_spring.clamp_min_bounce = true
		_initial_scale = _read_scale()


func _find_node() -> Node:
	if target_property.is_empty():
		return get_parent()
	var path_node := String(target_property.get_concatenated_names())
	if path_node.is_empty():
		return get_parent()
	return get_node_or_null(NodePath(path_node))


func _resolve_property() -> bool:
	match preset:
		Preset.PROPERTY:
			_property = NodePath("" if target_property.is_empty() else String(target_property.get_concatenated_subnames()))
			if _property.is_empty():
				push_warning("JuiceSpringNode '%s': target_property needs a property, like 'Sprite2D:modulate'." % name)
				return false
			return true
		Preset.POSITION:
			if not (_node is Node2D or _node is Node3D or _node is Control):
				return false
			_property = NodePath("global_position" if space == Space.GLOBAL else "position")
			return true
		Preset.ROTATION:
			if _node is Node3D or _node is Node2D:
				_property = NodePath("global_rotation_degrees" if space == Space.GLOBAL else "rotation_degrees")
			elif _node is Control:
				_property = NodePath("rotation_degrees")
			else:
				return false
			return true
		Preset.SCALE:
			if not (_node is Node2D or _node is Node3D or _node is Control):
				return false
			_property = NodePath("scale")
			return true
		Preset.SQUASH_AND_STRETCH:
			if not (_node is Node2D or _node is Node3D or _node is Control):
				return false
			_property = NodePath("scale")
			return true
	return false


func _read() -> Variant:
	if preset == Preset.TIME_SCALE:
		return Engine.time_scale
	if preset == Preset.SQUASH_AND_STRETCH:
		return 1.0
	var value: Variant = _node.get_indexed(_property)
	if value == null:
		value = _read_theme_override()
	if typeof(value) == TYPE_INT:
		_is_int = true
	return value


# A theme override has no value until it is set, so read what the theme gives instead.
func _read_theme_override() -> Variant:
	var control := _node as Control
	if control == null:
		return null
	var text := String(_property)
	var slash := text.find("/")
	if slash < 0:
		return null
	var item := text.substr(slash + 1)
	match text.substr(0, slash):
		"theme_override_font_sizes":
			return control.get_theme_font_size(item)
		"theme_override_constants":
			return control.get_theme_constant(item)
		"theme_override_colors":
			return control.get_theme_color(item)
	return null


func _write() -> void:
	if _spring == null:
		return
	var value: Variant = _spring.current
	match preset:
		Preset.TIME_SCALE:
			if not Engine.is_editor_hint():
				Engine.time_scale = maxf(float(value), 0.0)
		Preset.SQUASH_AND_STRETCH:
			_write_squash(float(value))
		_:
			if not is_instance_valid(_node):
				return
			if _is_int:
				value = roundi(float(value))
			_node.set_indexed(_property, value)


func _read_scale() -> Vector3:
	if not is_instance_valid(_node):
		return Vector3.ONE
	if _node is Node3D:
		return (_node as Node3D).scale
	var scale_2d: Vector2 = _node.get("scale")
	return Vector3(scale_2d.x, scale_2d.y, 1.0)


func _write_squash(factor: float) -> void:
	if not is_instance_valid(_node):
		return
	var inverse := 1.0 / sqrt(maxf(factor, 0.0001))
	var multipliers := Vector3.ONE
	match squash_axis:
		SquashAxis.X_TO_YZ:
			multipliers = Vector3(factor, inverse, inverse)
		SquashAxis.X_TO_Y:
			multipliers = Vector3(factor, inverse, 1.0)
		SquashAxis.X_TO_Z:
			multipliers = Vector3(factor, 1.0, inverse)
		SquashAxis.Y_TO_XZ:
			multipliers = Vector3(inverse, factor, inverse)
		SquashAxis.Y_TO_X:
			multipliers = Vector3(inverse, factor, 1.0)
		SquashAxis.Y_TO_Z:
			multipliers = Vector3(1.0, factor, inverse)
		SquashAxis.Z_TO_XZ:
			multipliers = Vector3(inverse, inverse, factor)
		SquashAxis.Z_TO_X:
			multipliers = Vector3(inverse, 1.0, factor)
		SquashAxis.Z_TO_Y:
			multipliers = Vector3(1.0, inverse, factor)
	var result := _initial_scale * multipliers
	if _node is Node3D:
		(_node as Node3D).scale = result
	else:
		_node.set("scale", Vector2(result.x, result.y))
