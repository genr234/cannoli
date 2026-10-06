@tool
@icon("res://addons/juice/icons/transform.svg")
class_name JuiceWiggle
extends JuiceFeedback
## Shakes the position, rotation and/or scale of a node at random, for a set time.
##
## Each of the three channels has its own duration and its own [JuiceWiggleSettings]
## (random, ping pong, noise or curve). When a channel ends the node goes back to the value
## it had when the play started. It works on Node2D, Node3D and Control. Rotation
## is in degrees; 2D nodes and controls rotate around z.

const _POSITION := 0
const _ROTATION := 1
const _SCALE := 2

@export_group("Position")
## Wiggles the position.
@export var wiggle_position: bool = true:
	set(value):
		wiggle_position = value
		notify_property_list_changed()
## Seconds the position wiggle lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var position_duration: float = 0.5
## How the position wiggles.
@export var position_settings: JuiceWiggleSettings = JuiceWiggleSettings.make_position()
@export_group("Rotation")
## Wiggles the rotation.
@export var wiggle_rotation: bool = false:
	set(value):
		wiggle_rotation = value
		notify_property_list_changed()
## Seconds the rotation wiggle lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var rotation_duration: float = 0.5
## How the rotation wiggles, in degrees.
@export var rotation_settings: JuiceWiggleSettings = JuiceWiggleSettings.make_rotation()
@export_group("Scale")
## Wiggles the scale.
@export var wiggle_scale: bool = false:
	set(value):
		wiggle_scale = value
		notify_property_list_changed()
## Seconds the scale wiggle lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var scale_duration: float = 0.5
## How the scale wiggles.
@export var scale_settings: JuiceWiggleSettings = JuiceWiggleSettings.make_scale()

var _initial: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _wigglers: Array[_Wiggler] = [_Wiggler.new(), _Wiggler.new(), _Wiggler.new()]


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name in ["position_duration", "position_settings"] and not wiggle_position:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["rotation_duration", "rotation_settings"] and not wiggle_rotation:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["scale_duration", "scale_settings"] and not wiggle_scale:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	var longest := 0.0
	for channel in 3:
		if _is_enabled(channel):
			longest = maxf(longest, _channel_duration(channel))
	return longest


func _get_category() -> StringName:
	return Juice.CATEGORY_SHAKE


func _on_initialize() -> void:
	# Own wigglers: duplicate() copies the array reference, not the state objects.
	_wigglers = [_Wiggler.new(), _Wiggler.new(), _Wiggler.new()]
	var node := get_target()
	if not _supported(node):
		return
	for channel in 3:
		_initial[channel] = _read(node, channel)


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _supported(node):
		return
	for channel in 3:
		var wiggler := _wigglers[channel]
		if not _is_enabled(channel):
			wiggler.active = false
			continue
		var origin: Vector3 = wiggler.origin if is_retrigger() and wiggler.has_origin else _read(node, channel)
		wiggler.start(_settings_for(channel), origin, apply_time_multiplier(_channel_duration(channel)), get_intensity())


func _on_tick() -> void:
	var node := get_target()
	if not _supported(node):
		return
	var dt := get_delta()
	for channel in 3:
		var wiggler := _wigglers[channel]
		if not wiggler.active:
			continue
		if wiggler.is_over():
			_finish_channel(node, channel)
		else:
			_write(node, channel, wiggler.step(dt))


func _on_finished() -> void:
	_settle()


func _on_stop() -> void:
	_settle()


func _on_skip_to_end() -> void:
	_settle()


func _on_restore() -> void:
	var node := get_target()
	if not _supported(node):
		return
	for channel in 3:
		_wigglers[channel].active = false
		_write(node, channel, _initial[channel])


# Puts every channel that is still wiggling back to its origin.
func _settle() -> void:
	var node := get_target()
	if not _supported(node):
		return
	for channel in 3:
		if _wigglers[channel].active:
			_finish_channel(node, channel)


func _finish_channel(node: Node, channel: int) -> void:
	var wiggler := _wigglers[channel]
	wiggler.active = false
	_write(node, channel, wiggler.origin)


func _is_enabled(channel: int) -> bool:
	match channel:
		_POSITION:
			return wiggle_position and position_settings != null
		_ROTATION:
			return wiggle_rotation and rotation_settings != null
	return wiggle_scale and scale_settings != null


func _channel_duration(channel: int) -> float:
	match channel:
		_POSITION:
			return position_duration
		_ROTATION:
			return rotation_duration
	return scale_duration


func _settings_for(channel: int) -> JuiceWiggleSettings:
	match channel:
		_POSITION:
			return position_settings
		_ROTATION:
			return rotation_settings
	return scale_settings


func _supported(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control


func _read(node: Node, channel: int) -> Vector3:
	if node is Node3D:
		var node_3d := node as Node3D
		match channel:
			_POSITION:
				return node_3d.position
			_ROTATION:
				return node_3d.rotation_degrees
		return node_3d.scale
	match channel:
		_POSITION:
			var point: Vector2 = node.position
			return Vector3(point.x, point.y, 0.0)
		_ROTATION:
			return Vector3(0.0, 0.0, node.rotation_degrees)
	var scale_2d: Vector2 = node.scale
	return Vector3(scale_2d.x, scale_2d.y, 1.0)


func _write(node: Node, channel: int, value: Vector3) -> void:
	if node is Node3D:
		var node_3d := node as Node3D
		match channel:
			_POSITION:
				node_3d.position = value
			_ROTATION:
				node_3d.rotation_degrees = value
			_:
				node_3d.scale = value
		return
	match channel:
		_POSITION:
			node.position = Vector2(value.x, value.y)
		_ROTATION:
			node.rotation_degrees = value.z
		_:
			node.scale = Vector2(value.x, value.y)


## The running state of one wiggled channel.
class _Wiggler:
	extends RefCounted

	var active := false
	var has_origin := false
	var origin := Vector3.ZERO

	var _settings: JuiceWiggleSettings
	var _duration := 0.0
	var _intensity := 1.0
	var _time := 0.0
	var _real := 0.0
	var _step_time := 0.0
	var _step_length := 0.0
	var _pause_left := 0.0
	var _from := Vector3.ZERO
	var _to := Vector3.ZERO
	var _last := Vector3.ZERO
	var _amplitude := Vector3.ZERO
	var _noise_frequency := Vector3.ZERO
	var _noise_shift := Vector3.ZERO
	var _remap_zero := Vector3.ZERO
	var _remap_one := Vector3.ONE
	var _forward := true
	var _to_high := true
	var _noise := FastNoiseLite.new()


	func start(settings: JuiceWiggleSettings, new_origin: Vector3, duration: float, intensity: float) -> void:
		_settings = settings
		origin = new_origin
		has_origin = true
		_duration = duration
		_intensity = intensity
		_time = 0.0
		_real = 0.0
		_pause_left = 0.0
		_forward = true
		_to_high = true
		_from = Vector3.ZERO
		_to = Vector3.ZERO
		_last = Vector3.ZERO
		active = true
		_amplitude = _roll_vector(settings.amplitude_min, settings.amplitude_max)
		if settings.force_vector_length:
			_amplitude = _amplitude.normalized() * settings.forced_vector_length
		_noise_frequency = _roll_vector(settings.noise_frequency_min, settings.noise_frequency_max)
		_noise_shift = _roll_vector(settings.noise_shift_min, settings.noise_shift_max)
		_remap_zero = _roll_vector(settings.remap_zero_min, settings.remap_zero_max)
		_remap_one = _roll_vector(settings.remap_one_min, settings.remap_one_max)
		_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		_noise.seed = randi()
		_noise.frequency = 1.0
		_begin_step(true)


	func is_over() -> bool:
		return _real >= _duration


	## Advances by [param delta] seconds and returns the value to write.
	func step(delta: float) -> Vector3:
		var dt := delta * _settings.time_multiplier
		_time += dt
		_real += delta
		if _settings.type == JuiceWiggleSettings.Type.NOISE:
			_last = _noise_offset()
		else:
			_last = _segment_offset(dt)
		# Relative adds the origin. Intensity is the share of the way from the origin.
		var absolute := origin + _last if _settings.relative else _last
		return origin.lerp(absolute, _intensity)


	func _falloff() -> float:
		var progress := clampf(_real / _duration, 0.0, 1.0) if _duration > 0.0 else 1.0
		if _settings.falloff == null:
			return 1.0 - progress
		return _settings.falloff.sample(progress)


	func _noise_offset() -> Vector3:
		var offset := Vector3(
			_noise.get_noise_2d(_noise_frequency.x * _time, _noise_shift.x),
			_noise.get_noise_2d(_noise_frequency.y * _time, _noise_shift.y),
			_noise.get_noise_2d(_noise_frequency.z * _time, _noise_shift.z)) * _amplitude
		if _settings.uniform_values:
			offset = Vector3(offset.x, offset.x, offset.x)
		return offset * _falloff()


	func _segment_offset(dt: float) -> Vector3:
		if _pause_left > 0.0:
			_pause_left -= dt
			return _last
		_step_time += dt
		var progress := 1.0 if _step_length <= 0.0 else clampf(_step_time / _step_length, 0.0, 1.0)
		var value: Vector3
		if _settings.type == JuiceWiggleSettings.Type.CURVE:
			var shaped := JuiceTween.sample(_settings.curve_tween, progress if _forward else 1.0 - progress)
			value = _remap_zero.lerp(_remap_one, shaped) * _falloff()
		else:
			value = _from.lerp(_to, JuiceTween.sample(_settings.step_tween, progress))
		if progress >= 1.0:
			_pause_left = randf_range(_settings.pause_min, _settings.pause_max)
			_begin_step(false)
		return value


	func _begin_step(first: bool) -> void:
		_step_time = 0.0
		_step_length = randf_range(_settings.frequency_min, _settings.frequency_max)
		match _settings.type:
			JuiceWiggleSettings.Type.RANDOM:
				_from = _to
				var target := _roll_vector(_settings.amplitude_min, _settings.amplitude_max)
				if _settings.force_vector_length:
					target = target.normalized() * _settings.forced_vector_length
				if _settings.uniform_values:
					target = Vector3(target.x, target.x, target.x)
				_to = target * _falloff()
			JuiceWiggleSettings.Type.PING_PONG:
				var low := _settings.amplitude_min
				var high := _settings.amplitude_max
				if _settings.uniform_values:
					low = Vector3(low.x, low.x, low.x)
					high = Vector3(high.x, high.x, high.x)
				_from = low * _falloff() if first else _to
				_to = (high if _to_high else low) * _falloff()
				_to_high = not _to_high
			JuiceWiggleSettings.Type.CURVE:
				if not first and _settings.curve_ping_pong:
					_forward = not _forward


	func _roll_vector(low: Vector3, high: Vector3) -> Vector3:
		return Vector3(randf_range(low.x, high.x), randf_range(low.y, high.y), randf_range(low.z, high.z))
