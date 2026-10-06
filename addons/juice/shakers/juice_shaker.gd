@tool
@icon("res://addons/juice/icons/shaker.svg")
@abstract
class_name JuiceShaker
extends Node
## The base of every shaker: a node that reacts to a feedback it cannot reference.
##
## A shaker listens to an event on the [Juice] bus, on one channel or on all of them.
## When a [JuiceFeedback] broadcasts that event, the shaker shakes its target for a
## while and then puts it back. Shakers run on their own [method Node._process], so they
## also work without a [JuicePlayer], through [method start_shaking] and [method shake].
##
## Shakers are additive. They never write an absolute value to the target, they add a
## small offset and take it away again. Several shakers (and feedbacks that add) can
## shake the same property at the same time, and the property returns exactly to its
## rest value once the last one is done.
##
## The target is the parent node unless [member target] points elsewhere.
## Subclasses override the [code]_get_events[/code], [code]_is_target_supported[/code],
## [code]_on_begin[/code] and [code]_shake[/code] hooks.

## Emitted when a shake begins. Not emitted again when a running shake restarts.
signal started
## Emitted when a shake ends, by itself or through [method stop].
signal stopped

@export_group("Channel")
## Listens to every channel and ignores [member channel] and [member channel_resource].
@export var listen_to_all_channels: bool = false:
	set(value):
		listen_to_all_channels = value
		_relisten()
## The channel to listen to. It has to match the channel of the feedback.
@export var channel: int = 0:
	set(value):
		channel = value
		_relisten()
## A channel resource to listen to instead of the number. It wins over [member channel].
@export var channel_resource: JuiceChannel:
	set(value):
		channel_resource = value
		_relisten()

@export_group("Shaker")
## The node to shake, relative to this shaker. Empty means the parent.
@export var target: NodePath = NodePath()
## How long one shake lasts, in seconds. A feedback usually sends its own duration.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var shake_duration: float = 0.2
## Starts shaking as soon as the node is ready. Never runs in the editor.
@export var play_on_ready: bool = false
## Shakes for as long as the node is in the tree, instead of ending after the duration.
@export var permanent_shake: bool = false
## Lets a new shake restart one that is still running. When off, new events are ignored while shaking.
@export var interruptible: bool = true
## Puts the target back after every shake, even when the feedback asked to keep the result.
@export var always_reset_after_shake: bool = false
## Ignores the values a feedback sends and uses only the values set on this shaker.
@export var only_use_shaker_values: bool = false
## Seconds after a shake starts during which no other shake can start.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var cooldown_between_shakes: float = 0.0
## Whether the shaker counts scaled or real time. A feedback overrides this with its own mode.
@export var timescale_mode: Juice.TimeMode = Juice.TimeMode.SCALED
## Runs a shake with the values of this shaker. Only works on the shaker in the tree you are editing.
@export_tool_button("Test shake", "Play") var test_button: Callable = start_shaking

## Added to every event name this shaker listens to. A feedback that drives one shaker on its own
## (the direct mode of the camera feedbacks) uses a suffix nobody else knows, so no other shaker hears it.
var event_suffix: String = ""

## True while the shaker plays the shake direction forward. Feedbacks that play reversed set it to false.
var forward_direction: bool = true

var _shaking: bool = false
var _journey: float = 0.0
var _duration: float = 0.0
var _elapsed: float = 0.0
var _reach: float = 1.0
var _run_permanent: bool = false
var _reset_target: bool = true
var _unscaled: bool = false
var _cooldown_left: float = 0.0
var _last_ticks: int = 0
var _listening: bool = false
var _offsets: Dictionary = {}
var _offset_node: Node

## Rest values and user counts of every property that some shaker currently offsets.
static var _claims: Dictionary = {}
static var _bump: Curve


# --- Node ------------------------------------------------------------------

func _enter_tree() -> void:
	_listen()


func _ready() -> void:
	set_process(false)
	if Engine.is_editor_hint():
		return
	if play_on_ready or permanent_shake:
		start_shaking()


func _exit_tree() -> void:
	_unlisten()
	if _shaking:
		_complete(true)
	clear_all_offsets()
	_on_exit()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var step := delta
	if _unscaled:
		step = float(now - _last_ticks) * 0.000001
	_last_ticks = now
	if _cooldown_left > 0.0:
		_cooldown_left -= step
	if _shaking:
		_step(step)
	_tick(step)
	if not (_shaking or _cooldown_left > 0.0 or _is_busy()):
		set_process(false)


# --- Public API ------------------------------------------------------------

## True while a shake is running.
func is_shaking() -> bool:
	return _shaking


## True during the cooldown that follows the start of a shake.
func is_in_cooldown() -> bool:
	return _cooldown_left > 0.0


## Starts a shake with the values of this shaker.
func start_shaking() -> void:
	shake({})


## Starts a shake. Keys in [param payload] replace the values of this shaker for this
## shake; the keys are the ones the matching feedback sends. An empty dictionary uses
## the shaker's own values. Range and channels are not checked here.
func shake(payload: Dictionary = {}) -> void:
	_begin(_get_events()[0], payload, 1.0)


## Ends the shake now. The target goes back to its rest values, unless the feedback
## that started the shake asked to keep the result and [member always_reset_after_shake] is off.
func stop() -> void:
	if _shaking:
		_complete(false)


## Ends the shake and puts the target back at its rest values for sure.
func restore() -> void:
	if _shaking:
		_complete(true)
	clear_all_offsets()
	_on_restore()


## The node this shaker works on: the node at [member target], or the parent.
func get_target_node() -> Node:
	if target.is_empty():
		return get_parent()
	return get_node_or_null(target)


## Adds [param offset] to a property of [param node] and remembers it, replacing the
## offset this shaker added before. [param property] may be an indexed path such as
## [code]position:x[/code]. Offsets of other shakers stay in place.
func set_offset(node: Node, property: String, offset: Variant) -> void:
	if _offset_node != node:
		clear_all_offsets()
		_offset_node = node
	var path := NodePath(property)
	if not _offsets.has(property):
		var key := _claim_key(node, property)
		var claim: Dictionary = _claims.get(key, {})
		if claim.is_empty():
			claim = {"rest": node.get_indexed(NodePath(_top_property(property))), "users": 0}
			_claims[key] = claim
		claim["users"] = int(claim["users"]) + 1
		_offsets[property] = Juice.scale_value(offset, 0.0)
	var old: Variant = _offsets[property]
	var change: Variant = Juice.add_values(offset, Juice.scale_value(old, -1.0))
	node.set_indexed(path, Juice.add_values(node.get_indexed(path), change))
	_offsets[property] = offset


## Takes back the offset this shaker added to [param property]. When no other shaker
## still offsets that property and the value is back within rounding of its rest value,
## the rest value is written so nothing drifts.
func clear_offset(property: String) -> void:
	if not _offsets.has(property):
		return
	var old: Variant = _offsets[property]
	_offsets.erase(property)
	var node := _offset_node
	if not is_instance_valid(node):
		return
	var path := NodePath(property)
	node.set_indexed(path, Juice.add_values(node.get_indexed(path), Juice.scale_value(old, -1.0)))
	var key := _claim_key(node, property)
	var claim: Dictionary = _claims.get(key, {})
	if claim.is_empty():
		return
	claim["users"] = int(claim["users"]) - 1
	if int(claim["users"]) > 0:
		return
	var top := NodePath(_top_property(property))
	var rest: Variant = claim["rest"]
	if _distance(node.get_indexed(top), rest) <= 0.0001 * maxf(1.0, _magnitude(rest)):
		node.set_indexed(top, rest)
	_claims.erase(key)


## Takes back every offset this shaker added.
func clear_all_offsets() -> void:
	for property: String in _offsets.keys():
		clear_offset(property)
	_offset_node = null


## The offset this shaker currently adds to [param property], or [param fallback] when none.
func get_offset(property: String, fallback: Variant = null) -> Variant:
	return _offsets.get(property, fallback)


## The value of [param property] without the offset this shaker added. Use it as the
## base to compute the next offset from.
func get_base_value(node: Node, property: String) -> Variant:
	var current: Variant = node.get_indexed(NodePath(property))
	if _offsets.has(property) and _offset_node == node:
		return Juice.add_values(current, Juice.scale_value(_offsets[property], -1.0))
	return current


## Starts the process loop. Subclasses call it after they gained work outside a normal shake.
func wake() -> void:
	_last_ticks = Time.get_ticks_usec()
	set_process(true)


## Reads [param curve] at [param progress] (0 to 1). An empty curve is a bump that rises from
## 0 to 1 at the middle and falls back to 0, which is what most shakes want.
static func sample_bump(curve: Curve, progress: float) -> float:
	if curve != null:
		return curve.sample(clampf(progress, 0.0, 1.0))
	if _bump == null:
		_bump = Curve.new()
		_bump.add_point(Vector2(0.0, 0.0))
		_bump.add_point(Vector2(0.5, 1.0))
		_bump.add_point(Vector2(1.0, 0.0))
	return _bump.sample(clampf(progress, 0.0, 1.0))


## Maps a curve to a value: the curve result 0 gives [param zero] and 1 gives [param one].
## An empty curve is a bump, see [method sample_bump].
static func sample_remap(curve: Curve, progress: float, zero: float, one: float) -> float:
	return lerpf(zero, one, sample_bump(curve, progress))


# --- Hooks for subclasses --------------------------------------------------

## The bus events this shaker listens to. The first one is used by [method shake].
func _get_events() -> Array[StringName]:
	return [&""]


## False when the shaker cannot work on [param node], for example a wrong node type.
func _is_target_supported(_node: Node) -> bool:
	return true


## A shake is starting, or restarting. Read the shake values from [param payload]
## (it is empty when the shaker's own values apply), and scale effects by [param reach].
## Set [code]_duration[/code] or [code]_run_permanent[/code] here when the shake needs
## another length. Return false to cancel the shake.
func _on_begin(_event: StringName, _payload: Dictionary, _reach: float) -> bool:
	return true


## Applies the shake. [param progress] runs from 0 to 1 over the shake (backwards when
## the shake is reversed) and [param seconds] counts the real seconds of the shake.
func _shake(_progress: float, _seconds: float) -> void:
	pass


## Called every frame while the process runs, shaking or not. Used by shakers with
## their own timers.
func _tick(_delta: float) -> void:
	pass


## True while the shaker still has work that needs frames, apart from a normal shake.
func _is_busy() -> bool:
	return false


## A shake ended and the offsets were cleared.
func _on_restore() -> void:
	pass


## The shaker leaves the tree.
func _on_exit() -> void:
	pass


## Called for an event after the stop, restore and range checks. The default starts a shake.
func _receive(event: StringName, payload: Dictionary, reach: float) -> void:
	_begin(event, payload, reach)


# --- Internals -------------------------------------------------------------

func _listen_channel() -> Variant:
	if listen_to_all_channels:
		return null
	if channel_resource != null:
		return channel_resource
	return channel


func _listen() -> void:
	_listening = true
	var channel_value := _listen_channel()
	for event in _get_events():
		if event != &"":
			Juice.listen(StringName(String(event) + event_suffix), channel_value, _on_event.bind(event))


func _unlisten() -> void:
	_listening = false
	for event in _get_events():
		if event != &"":
			Juice.unlisten(StringName(String(event) + event_suffix), _on_event.bind(event))


func _relisten() -> void:
	if _listening and is_inside_tree():
		_unlisten()
		_listen()


func _on_event(payload: Dictionary, event: StringName) -> void:
	if not is_inside_tree():
		return
	if payload.get("stop", false):
		stop()
		return
	if payload.get("restore", false):
		restore()
		return
	var reach := 1.0
	var values := payload
	if only_use_shaker_values:
		values = {}
	else:
		reach = Juice.get_range_multiplier(payload, _get_position())
		if reach <= 0.0:
			return
	_receive(event, values, reach)


# Where this shaker is for range checks: the target, or the closest spatial node above this one.
func _get_position() -> Vector3:
	var node: Node = get_target_node()
	if node == null:
		node = self
	while node != null and not (node is Node2D or node is Node3D or node is Control):
		node = node.get_parent()
	return Juice.node_position(node)


func _begin(event: StringName, payload: Dictionary, reach: float) -> void:
	if _cooldown_left > 0.0 or (_shaking and not interruptible):
		return
	var node := get_target_node()
	if node == null or not _is_target_supported(node):
		return
	_unscaled = int(payload.get("timescale_mode", timescale_mode)) == Juice.TimeMode.UNSCALED
	forward_direction = not bool(payload.get("reversed", false))
	_duration = float(payload.get("duration", shake_duration))
	_run_permanent = permanent_shake
	_reset_target = bool(payload.get("reset_target", true))
	_reach = reach
	if not _on_begin(event, payload, reach):
		return
	_cooldown_left = cooldown_between_shakes
	_journey = 0.0 if forward_direction else _duration
	_elapsed = 0.0
	var was_shaking := _shaking
	_shaking = true
	if not was_shaking:
		started.emit()
	wake()
	# A zero length shake still has to land on its final value.
	if _duration <= 0.0 and not _run_permanent:
		_complete(false)


func _progress() -> float:
	if _duration <= 0.0:
		return 1.0
	return clampf(_journey / _duration, 0.0, 1.0)


func _step(step: float) -> void:
	_elapsed += step
	_shake(_progress(), _elapsed)
	_journey += step if forward_direction else -step
	if _run_permanent:
		if _duration > 0.0:
			if _journey > _duration:
				_journey = 0.0
			elif _journey < 0.0:
				_journey = _duration
	elif _journey < 0.0 or _journey > _duration:
		_complete(false)


func _complete(force_reset: bool) -> void:
	_journey = _duration if forward_direction else 0.0
	_shake(_progress(), _elapsed)
	_shaking = false
	if force_reset or _reset_target or always_reset_after_shake:
		clear_all_offsets()
		_on_restore()
	stopped.emit()


# Offsets of "position" and "position:y" share one claim, so the rest value is written once, whole.
static func _top_property(property: String) -> String:
	return property.split(":")[0]


static func _claim_key(node: Node, property: String) -> String:
	return "%d:%s" % [node.get_instance_id(), _top_property(property)]


static func _magnitude(value: Variant) -> float:
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			return absf(float(value))
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_VECTOR4:
			return value.length()
		TYPE_COLOR:
			var color: Color = value
			return maxf(maxf(absf(color.r), absf(color.g)), maxf(absf(color.b), absf(color.a)))
	return 0.0


static func _distance(a: Variant, b: Variant) -> float:
	if typeof(a) != typeof(b):
		return INF
	return _magnitude(Juice.add_values(a, Juice.scale_value(b, -1.0)))
