@tool
@icon("res://addons/juice/icons/juice.svg")
class_name Juice
extends Object
## Static helpers shared by every Juice class.
##
## It holds the global on/off switch, the accessibility multipliers, the flash
## rate cap and the channel bus that feedbacks and shakers talk through. Nothing
## here needs a node or an autoload.

## Whether a timer runs on scaled time (affected by [member Engine.time_scale]) or real time.
enum TimeMode { SCALED, UNSCALED }
## The direction a [JuicePlayer] walks its feedback list.
enum Direction { FORWARD, BACKWARD }
## Restricts a feedback to one direction of its player.
enum DirectionCondition { ALWAYS, ONLY_FORWARD, ONLY_BACKWARD }
## How a feedback plays relative to its player's direction.
enum PlayDirection { FOLLOW_PLAYER, OPPOSITE_OF_PLAYER, ALWAYS_FORWARD, ALWAYS_BACKWARD }
## Where a feedback looks for its target when its target path is empty.
enum TargetMode { PARENT, SELF, FIRST_CHILD, CHILD_AT_INDEX, NONE }
## When a [JuicePlayer] builds its runtime feedbacks.
enum InitializationMode { MANUAL, ON_ENTER_TREE, ON_READY }

const SETTING_ENABLED := "juice/general/enabled"
const SETTING_FLASH_RATE_CAP := "juice/accessibility/flash_rate_cap"
const SETTING_PREFIX := "juice/accessibility/"
const SETTING_SUFFIX := "_intensity"

const CATEGORY_MOTION := &"motion"
const CATEGORY_SHAKE := &"shake"
const CATEGORY_FLASH := &"flash"
const CATEGORY_TIME := &"time"
const CATEGORY_AUDIO := &"audio"
const CATEGORY_HAPTICS := &"haptics"
const CATEGORY_OTHER := &"other"
const CATEGORIES: Array[StringName] = [
	CATEGORY_MOTION,
	CATEGORY_SHAKE,
	CATEGORY_FLASH,
	CATEGORY_TIME,
	CATEGORY_AUDIO,
	CATEGORY_HAPTICS,
	CATEGORY_OTHER,
]
const CATEGORY_COLORS: Dictionary[StringName, Color] = {
	CATEGORY_MOTION: Color("ff9f43"),
	CATEGORY_SHAKE: Color("ee5253"),
	CATEGORY_FLASH: Color("feca57"),
	CATEGORY_TIME: Color("54a0ff"),
	CATEGORY_AUDIO: Color("1dd1a1"),
	CATEGORY_HAPTICS: Color("a55eea"),
	CATEGORY_OTHER: Color("8395a7"),
}

## Broadcast when the range center should change for every player that listens.
const EVENT_RANGE_CENTER := &"juice_range_center"

static var _enabled := true
static var _multipliers: Dictionary[StringName, float] = {}
static var _flash_cap := -1.0
static var _flash_times: PackedFloat64Array = PackedFloat64Array()
static var _listeners: Dictionary[StringName, Array] = {}


# --- Global switch ---------------------------------------------------------

## Turns every [JuicePlayer] on or off at runtime.
static func set_enabled(value: bool) -> void:
	_enabled = value


## True when feedbacks may play. Both the runtime switch and the
## [code]juice/general/enabled[/code] project setting must allow it.
static func is_enabled() -> bool:
	return _enabled and bool(ProjectSettings.get_setting(SETTING_ENABLED, true))


# --- Accessibility ---------------------------------------------------------

## The project setting that stores the multiplier of [param category].
static func get_setting_path(category: StringName) -> String:
	return SETTING_PREFIX + String(category) + SETTING_SUFFIX


## The intensity multiplier of [param category]. A runtime override wins over
## the project setting. Unknown categories return 1.
static func get_multiplier(category: StringName) -> float:
	if _multipliers.has(category):
		return _multipliers[category]
	return maxf(0.0, float(ProjectSettings.get_setting(get_setting_path(category), 1.0)))


## Overrides the multiplier of [param category] until [method reset_multipliers] runs.
static func set_multiplier(category: StringName, value: float) -> void:
	_multipliers[category] = maxf(0.0, value)


## Drops the runtime overrides so the project settings apply again.
static func reset_multipliers() -> void:
	_multipliers.clear()
	_flash_cap = -1.0


## The most flashes per second that [method try_flash] allows. 0 means no cap.
static func get_flash_rate_cap() -> float:
	if _flash_cap >= 0.0:
		return _flash_cap
	return maxf(0.0, float(ProjectSettings.get_setting(SETTING_FLASH_RATE_CAP, 0.0)))


## Overrides the flash rate cap at runtime. Pass 0 to remove the cap.
static func set_flash_rate_cap(flashes_per_second: float) -> void:
	_flash_cap = maxf(0.0, flashes_per_second)


## Feedbacks that flash the screen call this before they start. It returns false
## when the flash rate cap has been reached, and the feedback should then skip.
static func try_flash() -> bool:
	var cap := get_flash_rate_cap()
	if cap <= 0.0:
		return true
	var now := unscaled_time()
	var kept := PackedFloat64Array()
	for time in _flash_times:
		if now - time < 1.0:
			kept.append(time)
	_flash_times = kept
	if _flash_times.size() >= int(ceilf(cap)):
		return false
	_flash_times.append(now)
	return true


## The default editor color of a feedback category.
static func get_category_color(category: StringName) -> Color:
	return CATEGORY_COLORS.get(category, CATEGORY_COLORS[CATEGORY_OTHER])


# --- Channel bus -----------------------------------------------------------

## True when two channels are the same. A channel is an int or a [JuiceChannel].
## [code]null[/code] matches everything, so a listener without a channel hears all.
static func channels_match(a: Variant, b: Variant) -> bool:
	if a == null or b == null:
		return true
	if a is JuiceChannel and b is JuiceChannel:
		return (a as JuiceChannel).matches(b as JuiceChannel)
	if a is int and b is int:
		return int(a) == int(b)
	return false


## Starts delivering [param event] on [param channel] to [param callable].
## The callable takes one [Dictionary], the payload. Listening twice with the same
## callable replaces the earlier channel.
static func listen(event: StringName, channel: Variant, callable: Callable) -> void:
	unlisten(event, callable)
	if not _listeners.has(event):
		_listeners[event] = []
	_listeners[event].append({"callable": callable, "channel": channel})


## Stops delivering [param event] to [param callable].
static func unlisten(event: StringName, callable: Callable) -> void:
	if not _listeners.has(event):
		return
	var list: Array = _listeners[event]
	for i in range(list.size() - 1, -1, -1):
		if (list[i]["callable"] as Callable) == callable:
			list.remove_at(i)
	if list.is_empty():
		_listeners.erase(event)


## Sends [param payload] to every listener of [param event] whose channel matches.
## Returns how many listeners received it. Listeners whose object was freed are dropped.
static func broadcast(event: StringName, channel: Variant, payload: Dictionary = {}) -> int:
	if not _listeners.has(event):
		return 0
	payload["channel"] = channel
	var delivered := 0
	var snapshot: Array = (_listeners[event] as Array).duplicate()
	for entry: Dictionary in snapshot:
		var callable: Callable = entry["callable"]
		if not callable.is_valid():
			unlisten(event, callable)
			continue
		if not channels_match(entry["channel"], channel):
			continue
		callable.call(payload)
		delivered += 1
	return delivered


## Removes every listener. Mostly useful when a game restarts its scene tree.
static func clear_listeners() -> void:
	_listeners.clear()


## Tells every listening [JuicePlayer] to use [param center] as its range center.
static func set_range_center(center: Node) -> void:
	broadcast(EVENT_RANGE_CENTER, null, {"center": center})


## Computes how strongly a listener at [param listener_position] reacts to a
## broadcast payload. Shakers call this with the payload they receive. It reads the
## keys [code]use_range[/code], [code]range_distance[/code], [code]range_falloff[/code],
## [code]range_remap[/code] and [code]position[/code] that [method JuiceFeedback.broadcast] adds.
## The result is 1 when the payload has no range.
static func get_range_multiplier(payload: Dictionary, listener_position: Vector3) -> float:
	if not bool(payload.get("use_range", false)):
		return 1.0
	var origin: Vector3 = payload.get("position", Vector3.ZERO)
	var distance := origin.distance_to(listener_position)
	var max_distance: float = payload.get("range_distance", 0.0)
	return range_falloff_value(distance, max_distance, bool(payload.get("use_range_falloff", false)),
			payload.get("range_falloff", null), payload.get("range_remap", Vector2(0.0, 1.0)))


## The shared falloff math of feedbacks, shakers and players. [param falloff] is a
## [Curve] over 0..1 of the distance, or null for a straight line from 1 to 0.
## [param remap] maps the curve's 0 and 1 to other values.
static func range_falloff_value(distance: float, max_distance: float, use_falloff: bool, falloff: Curve, remap: Vector2) -> float:
	if distance > max_distance:
		return 0.0
	if not use_falloff:
		return 1.0
	var normalized := 0.0 if max_distance <= 0.0 else distance / max_distance
	var value := 1.0 - normalized if falloff == null else falloff.sample(normalized)
	return lerpf(remap.x, remap.y, value)


# --- Helpers ---------------------------------------------------------------

## Seconds of real time, unaffected by [member Engine.time_scale].
static func unscaled_time() -> float:
	return float(Time.get_ticks_usec()) * 0.000001


## The world position of a [Node2D], [Node3D] or [Control] as a Vector3.
## Other nodes return [constant Vector3.ZERO].
static func node_position(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).global_position
	if node is Node2D:
		var point := (node as Node2D).global_position
		return Vector3(point.x, point.y, 0.0)
	if node is Control:
		var control_point := (node as Control).global_position
		return Vector3(control_point.x, control_point.y, 0.0)
	return Vector3.ZERO


## Converts a Vector3, Vector2, Node or null to a Vector3. [param fallback] is used for anything else.
static func to_vector3(value: Variant, fallback: Vector3 = Vector3.ZERO) -> Vector3:
	if value is Vector3:
		return value
	if value is Vector2:
		var point: Vector2 = value
		return Vector3(point.x, point.y, 0.0)
	if value is Node:
		return node_position(value as Node)
	return fallback


## Interpolates float, int, Vector2, Vector3, Vector4 and Color values.
## Any other type snaps to [param b] once [param weight] reaches 1. Weights outside
## 0..1 extrapolate for the supported types.
static func mix(a: Variant, b: Variant, weight: float) -> Variant:
	match typeof(a):
		TYPE_FLOAT, TYPE_INT:
			return lerpf(float(a), float(b), weight)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR:
			return a.lerp(b, weight)
	return b if weight >= 1.0 else a


## Adds two values of the same numeric, vector or color type.
## Other types return [param a].
static func add_values(a: Variant, b: Variant) -> Variant:
	match typeof(a):
		TYPE_FLOAT, TYPE_INT:
			return float(a) + float(b)
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR:
			return a + b
	return a


## Multiplies a numeric, vector or color value by [param factor].
## Other types return [param a].
static func scale_value(a: Variant, factor: float) -> Variant:
	match typeof(a):
		TYPE_FLOAT, TYPE_INT:
			return float(a) * factor
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4, TYPE_COLOR:
			return a * factor
	return a
