@tool
@icon("res://addons/juice/icons/spring.svg")
class_name JuiceSpring
extends Resource
## A damped spring that chases a target value.
##
## One class handles [float], [Vector2], [Vector3], [Vector4] and [Color]. The type is
## picked by [method setup] and every component is its own spring, so a Vector3 is three
## springs that share (or, with [member separate_axes], do not share) their settings.
## Internally everything is stored as a Vector4, which keeps the maths in one place.
##
## The spring is a plain value helper: it never touches a node. Call [method update] each
## frame and read [member current]. [JuiceSpringNode] and the spring feedbacks do that for you.
##
## Settings live in exported properties, runtime state (current, target, velocity) does not.
## [method Resource.duplicate] therefore gives a clean spring with the same settings.

## What a spring does when it receives a command, from a feedback or the event bus.
enum Command {
	MOVE_TO,
	MOVE_TO_ADDITIVE,
	MOVE_TO_SUBTRACTIVE,
	MOVE_TO_RANDOM,
	MOVE_TO_INSTANT,
	BUMP,
	BUMP_RANDOM,
	STOP,
	FINISH,
	RESTORE,
	RESET_INITIAL,
}
## The kinds of value a spring can hold.
enum ValueType { NONE, FLOAT, VECTOR2, VECTOR3, VECTOR4, COLOR }

const _FIXED_STEP := 1.0 / 60.0

@export_group("Spring")
## How fast the spring calms down. Low values keep oscillating for a long time, 1 stops
## without overshooting.
@export_range(0.01, 1.0, 0.01) var damping: float = 0.4
## How many oscillations per second the spring makes when it is disturbed.
@export_range(0.1, 40.0, 0.1, "or_greater", "suffix:Hz") var frequency: float = 6.0
## Gives every component its own damping and frequency.
@export var separate_axes: bool = false:
	set(value):
		separate_axes = value
		notify_property_list_changed()
## Damping per component (x, y, z, w or r, g, b, a). Used when [member separate_axes] is on.
@export var axis_damping: Vector4 = Vector4(0.4, 0.4, 0.4, 0.4)
## Frequency per component. Used when [member separate_axes] is on.
@export var axis_frequency: Vector4 = Vector4(6.0, 6.0, 6.0, 6.0)

@export_group("Clamp")
## Keeps the spring from going below the minimum.
@export var clamp_min: bool = false:
	set(value):
		clamp_min = value
		notify_property_list_changed()
## The lowest value per component.
@export var clamp_min_value: Vector4 = Vector4.ZERO
## Uses the initial value as the minimum instead of [member clamp_min_value].
@export var clamp_min_initial: bool = false
## Mirrors the spring back above the minimum instead of flattening it there.
@export var clamp_min_bounce: bool = false
## Keeps the spring from going above the maximum.
@export var clamp_max: bool = false:
	set(value):
		clamp_max = value
		notify_property_list_changed()
## The highest value per component.
@export var clamp_max_value: Vector4 = Vector4(10.0, 10.0, 10.0, 10.0)
## Uses the initial value as the maximum instead of [member clamp_max_value].
@export var clamp_max_initial: bool = false
## Mirrors the spring back below the maximum instead of flattening it there.
@export var clamp_max_bounce: bool = false

## The value being shown. Setting it jumps there without changing the target.
var current: Variant:
	get:
		return _from_vector(_shown)
	set(value):
		_actual = _coerce(value)
		_shown = _actual
## The value the spring is heading to. Targets are clamped by the clamp settings.
var target: Variant:
	get:
		return _from_vector(_target)
	set(value):
		_target = _clamp_target(_coerce(value))
## The current speed of the spring.
var velocity: Variant:
	get:
		return _from_vector(_velocity)
	set(value):
		_velocity = _coerce(value)
## The value the spring goes back to on [method restore_initial].
var initial: Variant:
	get:
		return _from_vector(_initial)
	set(value):
		_initial = _coerce(value)

var _type: ValueType = ValueType.NONE
var _actual := Vector4.ZERO
var _shown := Vector4.ZERO
var _target := Vector4.ZERO
var _velocity := Vector4.ZERO
var _initial := Vector4.ZERO


# --- Type helpers ----------------------------------------------------------

## The [enum ValueType] a Variant maps to. Integers count as floats. Unsupported values
## give [constant NONE].
static func value_type_of(value: Variant) -> ValueType:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			return ValueType.FLOAT
		TYPE_VECTOR2:
			return ValueType.VECTOR2
		TYPE_VECTOR3:
			return ValueType.VECTOR3
		TYPE_VECTOR4:
			return ValueType.VECTOR4
		TYPE_COLOR:
			return ValueType.COLOR
	return ValueType.NONE


## How many components a value of [param type] has.
static func component_count(type: ValueType) -> int:
	match type:
		ValueType.FLOAT:
			return 1
		ValueType.VECTOR2:
			return 2
		ValueType.VECTOR3:
			return 3
		ValueType.VECTOR4, ValueType.COLOR:
			return 4
	return 0


## A rough time in seconds a disturbed spring needs to fall under [param precision] of its
## starting swing. Springs never stop for real, so this is an estimate to size durations.
static func estimate_settle_time(damping_ratio: float, frequency_hz: float, precision: float = 0.005) -> float:
	var omega := maxf(frequency_hz, 0.01) * TAU
	var decay := maxf(damping_ratio, 0.01) * omega
	return log(1.0 / clampf(precision, 0.000001, 0.5)) / decay


## Same as the static version, using the slowest component of this spring.
func get_settle_time(precision: float = 0.005) -> float:
	if not separate_axes:
		return estimate_settle_time(damping, frequency, precision)
	var slowest := 0.0
	for i in 4:
		slowest = maxf(slowest, estimate_settle_time(axis_damping[i], axis_frequency[i], precision))
	return slowest


## The type this spring holds, set by [method setup].
func get_value_type() -> ValueType:
	return _type


func _validate_property(property: Dictionary) -> void:
	var prop_name: String = property.name
	if prop_name in ["damping", "frequency"] and separate_axes:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["axis_damping", "axis_frequency"] and not separate_axes:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["clamp_min_value", "clamp_min_initial", "clamp_min_bounce"] and not clamp_min:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["clamp_max_value", "clamp_max_initial", "clamp_max_bounce"] and not clamp_max:
		property.usage &= ~PROPERTY_USAGE_EDITOR


# --- Setup and settings ----------------------------------------------------

## Chooses the value type from [param start_value] and puts the spring at rest on it.
## The value also becomes the initial value. Returns false for unsupported types.
func setup(start_value: Variant) -> bool:
	var type := value_type_of(start_value)
	if type == ValueType.NONE:
		return false
	_type = type
	_actual = _coerce(start_value)
	_shown = _actual
	_target = _actual
	_velocity = Vector4.ZERO
	_initial = _actual
	return true


## Sets the damping. A float sets every component, a vector sets each one and turns
## [member separate_axes] on.
func set_damping(value: Variant) -> void:
	var packed := _coerce(value)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		damping = packed.x
		axis_damping = packed
		return
	damping = packed.x
	axis_damping = packed
	separate_axes = true


## Sets the frequency. A float sets every component, a vector sets each one and turns
## [member separate_axes] on.
func set_frequency(value: Variant) -> void:
	var packed := _coerce(value)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		frequency = packed.x
		axis_frequency = packed
		return
	frequency = packed.x
	axis_frequency = packed
	separate_axes = true


# --- Simulation ------------------------------------------------------------

## Advances the spring by [param delta] seconds. Long frames are split into steps of
## 1/60 s so the spring stays stable.
func update(delta: float) -> void:
	if _type == ValueType.NONE or delta <= 0.0:
		return
	var count := component_count(_type)
	for i in count:
		var spring_damping := axis_damping[i] if separate_axes else damping
		var spring_frequency := axis_frequency[i] if separate_axes else frequency
		var omega := spring_frequency * TAU
		var stiffness := omega * omega
		var friction := 2.0 * spring_damping * omega
		var position := _actual[i]
		var speed := _velocity[i]
		var goal := _target[i]
		var remaining := delta
		while remaining > 0.0:
			var step := minf(remaining, _FIXED_STEP)
			speed += step * (-stiffness * (position - goal) - friction * speed)
			position += step * speed
			remaining -= step
		_actual[i] = position
		_velocity[i] = speed
	_shown = _apply_clamp(_actual)


## True when the spring is nearly at rest on its target.
func is_settled(velocity_threshold: float = 0.001, distance_threshold: float = 0.001) -> bool:
	var count := component_count(_type)
	var speed := 0.0
	var distance := 0.0
	for i in count:
		speed += absf(_velocity[i])
		distance += absf(_actual[i] - _target[i])
	return speed < velocity_threshold and distance < distance_threshold


## Sets a new target.
func move_to(value: Variant) -> void:
	target = value


## Moves the target by [param amount].
func move_to_additive(amount: Variant) -> void:
	_target = _clamp_target(_target + _coerce(amount))


## Moves the target back by [param amount].
func move_to_subtractive(amount: Variant) -> void:
	_target = _clamp_target(_target - _coerce(amount))


## Picks a random target between [param min_value] and [param max_value], per component.
func move_to_random(min_value: Variant, max_value: Variant) -> void:
	_target = _clamp_target(_random_between(_coerce(min_value), _coerce(max_value)))


## Jumps to [param value] and rests there.
func move_to_instant(value: Variant) -> void:
	var packed := _coerce(value)
	_actual = packed
	_shown = packed
	_target = _clamp_target(packed)
	_velocity = Vector4.ZERO


## Adds [param amount] to the speed. This kicks the spring without moving its target.
func bump(amount: Variant) -> void:
	_velocity += _coerce(amount)


## Adds a random speed between [param min_value] and [param max_value], per component.
func bump_random(min_value: Variant, max_value: Variant) -> void:
	_velocity += _random_between(_coerce(min_value), _coerce(max_value))


## Stops where it is: no speed, and the target becomes the current value.
func stop() -> void:
	_velocity = Vector4.ZERO
	_target = _clamp_target(_actual)


## Snaps to the target at once.
func finish() -> void:
	_velocity = Vector4.ZERO
	_actual = _target
	_shown = _apply_clamp(_actual)


## Goes back to the initial value and rests there.
func restore_initial() -> void:
	_actual = _initial
	_shown = _initial
	_velocity = Vector4.ZERO
	_target = _clamp_target(_initial)


## Makes the current value the new initial value.
func set_current_as_initial() -> void:
	_initial = _actual


## Runs a command from a feedback or the event bus. Recognized keys of [param data]:
## [code]command[/code] ([enum Command]), [code]value[/code], [code]bump[/code],
## [code]min[/code], [code]max[/code], [code]bump_min[/code], [code]bump_max[/code],
## [code]override_damping[/code] with [code]damping[/code], and
## [code]override_frequency[/code] with [code]frequency[/code]. Values may be any supported
## type; they are converted to the type of this spring.
func apply_command(data: Dictionary) -> void:
	if _type == ValueType.NONE:
		return
	if bool(data.get("override_damping", false)) and data.has("damping"):
		set_damping(data["damping"])
	if bool(data.get("override_frequency", false)) and data.has("frequency"):
		set_frequency(data["frequency"])
	var command: int = data.get("command", Command.BUMP)
	match command:
		Command.MOVE_TO:
			move_to(data.get("value", 0.0))
		Command.MOVE_TO_ADDITIVE:
			move_to_additive(data.get("value", 0.0))
		Command.MOVE_TO_SUBTRACTIVE:
			move_to_subtractive(data.get("value", 0.0))
		Command.MOVE_TO_RANDOM:
			move_to_random(data.get("min", 0.0), data.get("max", 0.0))
		Command.MOVE_TO_INSTANT:
			move_to_instant(data.get("value", 0.0))
		Command.BUMP:
			bump(data.get("bump", 0.0))
		Command.BUMP_RANDOM:
			bump_random(data.get("bump_min", 0.0), data.get("bump_max", 0.0))
		Command.STOP:
			stop()
		Command.FINISH:
			finish()
		Command.RESTORE:
			restore_initial()
		Command.RESET_INITIAL:
			set_current_as_initial()


# --- Internals -------------------------------------------------------------

# Packs any supported value into a Vector4. A float fills every component, so a plain
# number can drive a vector spring. Missing components of shorter vectors are 0.
func _coerce(value: Variant) -> Vector4:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			var number := float(value)
			return Vector4(number, number, number, number)
		TYPE_VECTOR2:
			var vec2: Vector2 = value
			return Vector4(vec2.x, vec2.y, 0.0, 0.0)
		TYPE_VECTOR3:
			var vec3: Vector3 = value
			return Vector4(vec3.x, vec3.y, vec3.z, 0.0)
		TYPE_VECTOR4:
			return value
		TYPE_COLOR:
			var color: Color = value
			return Vector4(color.r, color.g, color.b, color.a)
	return Vector4.ZERO


func _from_vector(packed: Vector4) -> Variant:
	match _type:
		ValueType.FLOAT:
			return packed.x
		ValueType.VECTOR2:
			return Vector2(packed.x, packed.y)
		ValueType.VECTOR3:
			return Vector3(packed.x, packed.y, packed.z)
		ValueType.VECTOR4:
			return packed
		ValueType.COLOR:
			return Color(packed.x, packed.y, packed.z, packed.w)
	return null


func _random_between(low: Vector4, high: Vector4) -> Vector4:
	var result := Vector4.ZERO
	for i in 4:
		result[i] = randf_range(low[i], high[i])
	return result


func _min_for(index: int) -> float:
	return _initial[index] if clamp_min_initial else clamp_min_value[index]


func _max_for(index: int) -> float:
	return _initial[index] if clamp_max_initial else clamp_max_value[index]


# Targets are only held inside the range, never mirrored.
func _clamp_target(packed: Vector4) -> Vector4:
	if not clamp_min and not clamp_max:
		return packed
	var result := packed
	for i in component_count(_type):
		if clamp_min and result[i] < _min_for(i):
			result[i] = _min_for(i)
		if clamp_max and result[i] > _max_for(i):
			result[i] = _max_for(i)
	return result


# The shown value is clamped or mirrored, while the simulation keeps its real position.
func _apply_clamp(packed: Vector4) -> Vector4:
	if not clamp_min and not clamp_max:
		return packed
	var result := packed
	for i in component_count(_type):
		var low := _min_for(i)
		var high := _max_for(i)
		if clamp_min and packed[i] < low:
			result[i] = absf(packed[i] - low) + low if clamp_min_bounce else maxf(packed[i], low)
		if clamp_max and packed[i] > high:
			result[i] = high - (packed[i] - high) if clamp_max_bounce else minf(packed[i], high)
	return result
