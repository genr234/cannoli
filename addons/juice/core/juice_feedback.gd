@tool
@abstract
@icon("res://addons/juice/icons/feedback.svg")
class_name JuiceFeedback
extends Resource
## One effect in a [JuicePlayer]'s list, such as moving a node or pausing the sequence.
##
## A feedback is a resource, so it can be saved as a preset. The player never plays
## the resource you edited. It duplicates it on initialization and plays the copy, so
## runtime state never leaks between players. Subclasses override the virtual
## methods named [code]_on_*[/code] and [code]_get_*[/code]. Everything else here is
## shared timing, repeat, chance, intensity and target logic.
##
## Every subclass script must start with [code]@tool[/code] so the inspector can hide
## options that do not apply, and should begin its own exports with an
## [code]@export_group[/code].

enum _State { IDLE, DELAY, RUNNING, REPEAT_WAIT }

# Absorbs float error so that ten 0.01 s frames really add up to 0.1 s.
const _EPSILON := 0.000001

## Inactive feedbacks are skipped by the player.
@export var active: bool = true
## A name shown in the editor. Empty uses the default name of the feedback type.
@export var label: String = ""
## The odds, in percent, that this feedback plays when reached.
@export_range(0.0, 100.0, 0.1) var chance: float = 100.0

@export_group("Channel")
## The integer channel this feedback broadcasts on. Shakers with the same channel react.
@export var channel: int = 0
## A channel resource. When set it replaces [member channel].
@export var channel_resource: JuiceChannel

@export_group("Target")
## The node to affect, relative to the player. Empty uses [member automatic_target_mode].
@export var target: NodePath = NodePath()
## Where to look for the target when [member target] is empty.
@export var automatic_target_mode: Juice.TargetMode = Juice.TargetMode.PARENT
## The child index used by CHILD_AT_INDEX.
@export var automatic_child_index: int = 0

@export_group("Timing")
## Scaled time follows [member Engine.time_scale]. Unscaled time ignores it.
@export var timescale_mode: Juice.TimeMode = Juice.TimeMode.SCALED
## When true, holding pauses and the player's end do not wait for this feedback.
@export var exclude_from_holding_pauses: bool = false
## When false, this feedback is left out of the player's total duration.
@export var contribute_to_total_duration: bool = true
## Seconds to wait before playing.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var initial_delay: float = 0.0
## Seconds that must pass after a play before this feedback can play again.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var cooldown: float = 0.0
## When true, stopping the player interrupts this feedback. When false it finishes on its own.
@export var interrupts_on_stop: bool = true
## How many extra times to play after the first.
@export_range(0, 100, 1, "or_greater") var repeats: int = 0
## Plays again and again until the player is stopped.
@export var repeat_forever: bool = false
## Seconds between the end of one play and the start of the next.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var delay_between_repeats: float = 0.0
## Limits how many times this feedback can play.
@export var limit_play_count: bool = false
## The most plays allowed when [member limit_play_count] is on.
@export_range(1, 100, 1, "or_greater") var max_play_count: int = 3
## Sets the play count back to zero each time the player starts.
@export var reset_play_count_on_reset: bool = false
## Plays only when the player goes in the chosen direction.
@export var direction_condition: Juice.DirectionCondition = Juice.DirectionCondition.ALWAYS
## Plays forward or in reverse, relative to the player's direction.
@export var play_direction: Juice.PlayDirection = Juice.PlayDirection.FOLLOW_PLAYER
## Ignores the player's intensity and always uses 1.
@export var constant_intensity: bool = false
## Plays only when the incoming intensity is in the interval below.
@export var use_intensity_interval: bool = false
## The lowest intensity that plays, inclusive.
@export var intensity_min: float = 0.0
## The intensity this feedback stops playing at, exclusive.
@export var intensity_max: float = 1.0
## Delays the start to the next beat of a global beat grid.
@export var quantize_to_bpm: bool = false
## Beats per minute of the grid.
@export_range(1.0, 400.0, 0.1, "or_greater") var bpm: float = 120.0
## The grid step in beats. 0.5 snaps to eighth notes at four beats per bar.
@export_range(0.0625, 8.0, 0.0625, "or_greater") var quantize_beats: float = 1.0

@export_group("Randomness")
## Multiplies the intensity by a random value each play.
@export var randomize_output: bool = false
## The random intensity multiplier range, x is the minimum and y the maximum.
@export var random_multiplier: Vector2 = Vector2(0.8, 1.0)
## Multiplies the duration by a random value each time the player starts.
@export var randomize_duration: bool = false
## The random duration multiplier range, x is the minimum and y the maximum.
@export var random_duration_multiplier: Vector2 = Vector2(0.5, 2.0)

@export_group("Range")
## Only listeners within the range react to what this feedback broadcasts.
@export var use_range: bool = false
## The reach of the broadcast, in world units.
@export var range_distance: float = 5.0
## Weakens the effect with distance.
@export var use_range_falloff: bool = false
## The falloff over 0..1 of the distance. Null is a straight line from 1 to 0.
@export var range_falloff: Curve
## Maps the falloff curve's 0 and 1 to these values.
@export var remap_range_falloff: Vector2 = Vector2(0.0, 1.0)

## The player that owns this runtime copy. Null on the resource you edit.
var player: JuicePlayer

var _state: _State = _State.IDLE
var _initialized := false
var _index := 0
var _timer := 0.0
var _elapsed := 0.0
var _run_duration := 0.0
var _reversed := false
var _intensity := 1.0
var _incoming_intensity := 1.0
var _position := Vector3.ZERO
var _plays_left := 0
var _play_count := 0
var _cooldown_left := 0.0
var _random_duration := 1.0
var _delta := 0.0
var _session_started := false
var _no_more_repeats := false
var _retrigger_flag := false
var _target_cache: Node


func _validate_property(property: Dictionary) -> void:
	var prop_name: String = property.name
	var hidden := false
	match prop_name:
		"Channel", "channel", "channel_resource":
			hidden = not _has_channel()
		"Target", "target", "automatic_target_mode":
			hidden = not _has_target()
		"automatic_child_index":
			hidden = not _has_target() or automatic_target_mode != Juice.TargetMode.CHILD_AT_INDEX
		"Range", "use_range", "range_distance", "use_range_falloff", "range_falloff", "remap_range_falloff":
			hidden = not _has_range()
		"Randomness", "randomize_output", "random_multiplier", "randomize_duration", "random_duration_multiplier":
			hidden = not _has_randomness()
	if not hidden:
		return
	if property.usage & PROPERTY_USAGE_GROUP:
		property.usage = PROPERTY_USAGE_NONE
	else:
		property.usage &= ~PROPERTY_USAGE_EDITOR


# --- Virtual API for subclasses --------------------------------------------

## Override to return the length of one play in seconds, before the player's
## multipliers. Return 0 for an instant feedback. Must not depend on runtime state.
func _get_duration() -> float:
	return 0.0


## Called once when the player initializes, on the runtime copy. Look up targets
## and store the initial values here.
func _on_initialize() -> void:
	pass


## Called each time the feedback starts, after the initial delay. [param feedback_intensity]
## already includes the player's intensity, randomness, range and the category multiplier.
## Instant feedbacks do all their work here.
func _on_play(_feedback_intensity: float) -> void:
	pass


## Called right after [method _on_play] and then every frame while the feedback runs,
## ending with exactly 1 (or 0 in reverse). [param progress] is direction aware. It
## already runs from 1 to 0 when the feedback plays in reverse. Only called when
## [method _get_duration] is above 0.
func _on_progress(_progress: float) -> void:
	pass


## Called every frame while a duration-based feedback runs, after [method _on_progress].
## Use [method get_delta] for the frame time. Optional.
func _on_tick() -> void:
	pass


## Called when one play ends by itself, after the final [method _on_progress].
func _on_finished() -> void:
	pass


## Called when the player stops and [member interrupts_on_stop] is true. It can run
## while the feedback is idle, so check that the feedback was initialized.
func _on_stop() -> void:
	pass


## Called when the player skips to the end, after the final [method _on_progress].
## Instant feedbacks need nothing here.
func _on_skip_to_end() -> void:
	pass


## Called when the player restores initial values. Put the target back the way
## [method _on_initialize] found it.
func _on_restore() -> void:
	pass


## Called when the player is freed while this feedback is still busy, so global
## changes such as the time scale or a screen flash do not outlive it. The player is
## already out of the tree, so [method get_target] only returns a cached node.
## The default calls [method _on_stop].
func _on_released() -> void:
	_on_stop()


## Called each time the player starts a new play, before the sequence runs.
func _on_reset() -> void:
	pass


## Called when the player's sequence finishes.
func _on_player_complete() -> void:
	pass


## The category used for accessibility multipliers and the default color. One of the
## [code]Juice.CATEGORY_*[/code] values.
func _get_category() -> StringName:
	return Juice.CATEGORY_OTHER


## The editor color of this feedback. The default comes from the category.
func _get_color() -> Color:
	return Juice.get_category_color(_get_category())


## The default name shown in the editor, derived from the script file name.
func _get_display_label() -> String:
	var script_path := ""
	var script: Script = get_script()
	if script != null:
		script_path = script.resource_path
	var base := script_path.get_file().get_basename().trim_prefix("juice_")
	return base.capitalize()


## Return true to show the Channel group.
func _has_channel() -> bool:
	return false


## Return true to show the Range group.
func _has_range() -> bool:
	return false


## Return true to show the Randomness group.
func _has_randomness() -> bool:
	return true


## Return true to show the Target group.
func _has_target() -> bool:
	return true


## Return true if the sequence waits after this feedback plays. See [JuicePause].
func _is_pause() -> bool:
	return false


## Return true if the sequence first waits for earlier feedbacks to finish. See [JuiceHoldingPause].
func _is_holding_pause() -> bool:
	return false


## Return true if this feedback jumps the sequence back. See [JuiceLooper].
func _is_looper() -> bool:
	return false


## Return true if this feedback is a place for a looper to jump back to. See [JuiceLooperStart].
func _is_looper_start() -> bool:
	return false


## For pauses, the raw wait in seconds before the player's multipliers.
## The default is [method _get_duration].
func _get_pause_duration() -> float:
	return _get_duration()


## For pauses, return true to wait until [method JuicePlayer.resume] is called.
func _is_script_driven_pause() -> bool:
	return false


## For script driven pauses, the seconds after which the pause resumes by itself.
## 0 means never.
func _get_auto_resume() -> float:
	return 0.0


## For loopers, whether the sequence should jump back after this play.
func _is_loop_pending() -> bool:
	return false


## For loopers, the total number of passes through the loop, or 0 when it never ends.
## Used for total duration.
func _get_loop_count() -> int:
	return 1


## For loopers, jump back to the last pause when true.
func _loops_to_last_pause() -> bool:
	return true


## For loopers, jump back to the last looper start when true.
func _loops_to_last_looper_start() -> bool:
	return true


# --- Helpers for subclasses ------------------------------------------------

## The node this feedback affects. Resolves [member target], or the automatic
## target when the path is empty. The result is cached until the node is freed.
func get_target() -> Node:
	if is_instance_valid(_target_cache):
		return _target_cache
	_target_cache = resolve(target)
	return _target_cache


## Finds a node from a path relative to the player. An empty path, or a path that
## only holds a property such as ":modulate", uses the automatic target. Property
## parts of a path are ignored here.
func resolve(path: NodePath) -> Node:
	if player == null or not player.is_inside_tree():
		return null
	if path.get_name_count() > 0:
		var node_only := NodePath(path.get_concatenated_names())
		if path.is_absolute():
			node_only = NodePath("/" + path.get_concatenated_names())
		return player.get_node_or_null(node_only)
	match automatic_target_mode:
		Juice.TargetMode.PARENT:
			return player.get_parent()
		Juice.TargetMode.SELF:
			return player
		Juice.TargetMode.FIRST_CHILD:
			return player.get_child(0) if player.get_child_count() > 0 else null
		Juice.TargetMode.CHILD_AT_INDEX:
			if automatic_child_index >= 0 and automatic_child_index < player.get_child_count():
				return player.get_child(automatic_child_index)
	return null


## Forgets the cached target so the next [method get_target] looks it up again.
func refresh_target() -> void:
	_target_cache = null


## The intensity of the current play, after every multiplier.
func get_intensity() -> float:
	return _intensity


## The intensity the player asked for, before this feedback's own multipliers.
func get_incoming_intensity() -> float:
	return _incoming_intensity


## True when the current play runs in reverse. Fixed for the length of one play.
func is_reversed() -> bool:
	return _reversed


## True when the current trigger continues a play that has not fully ended: a repeat,
## or a restart while still running. Do not capture origin values again then.
func is_retrigger() -> bool:
	return _retrigger_flag


## The frame time of the current tick, in this feedback's timescale mode.
func get_delta() -> float:
	return _delta


## Seconds since the current play started.
func get_elapsed() -> float:
	return _elapsed


## The world position the player was asked to play at.
func get_play_position() -> Vector3:
	return _position


## True while a play is running. Delays and repeat waits do not count.
func is_playing() -> bool:
	return _state == _State.RUNNING


## True while anything is pending: a delay, a play or a repeat wait.
func is_busy() -> bool:
	return _state != _State.IDLE


## True when the player should wait for this feedback. Busy and not excluded.
func blocks_player() -> bool:
	return _state != _State.IDLE and not exclude_from_holding_pauses


## How many times this feedback has played since the last reset.
func get_play_count() -> int:
	return _play_count


## True once the player has initialized this runtime copy.
func is_initialized() -> bool:
	return _initialized


## The position of this feedback in the player's runtime list.
func get_index() -> int:
	return _index


## The channel to broadcast on. An int, or a [JuiceChannel] when one is set.
func get_channel() -> Variant:
	if channel_resource != null:
		return channel_resource
	return channel


## The timescale mode in use. A player can force one for all of its feedbacks.
func get_effective_timescale_mode() -> Juice.TimeMode:
	if player != null and player.force_timescale_mode:
		return player.forced_timescale_mode
	return timescale_mode


## Applies the player's duration multiplier, timescale multiplier and this feedback's
## random duration multiplier to [param seconds]. Use it for any duration you compute.
func apply_time_multiplier(seconds: float) -> float:
	return _apply_multiplier(seconds, player)


## The duration of one play in seconds, with every multiplier applied.
func get_feedback_duration() -> float:
	return apply_time_multiplier(_get_duration())


## The time this feedback adds to the player's total duration, with initial delay
## and repeats. A repeat forever counts as a single play.
func compute_total_duration(for_player: JuicePlayer = null) -> float:
	if not contribute_to_total_duration:
		return 0.0
	var source := for_player if for_player != null else player
	var duration := _apply_multiplier(_get_duration(), source)
	var total := _apply_multiplier(initial_delay, source) + duration
	if repeats > 0 and not repeat_forever:
		total += float(repeats) * (duration + _apply_multiplier(delay_between_repeats, source))
	return total


## The pause length in seconds with every multiplier applied. Only meaningful when
## [method _is_pause] is true.
func get_pause_duration(for_player: JuicePlayer = null) -> float:
	var source := for_player if for_player != null else player
	return _apply_multiplier(_get_pause_duration(), source)


## Scales a value by how close a listener is, using this feedback's range settings.
## Returns 1 when [member use_range] is off.
func get_range_multiplier(listener_position: Vector3) -> float:
	if not use_range:
		return 1.0
	var distance := _position.distance_to(listener_position)
	return Juice.range_falloff_value(distance, range_distance, use_range_falloff, range_falloff, remap_range_falloff)


## Sends a message to listening shakers on this feedback's channel. The payload gets
## the keys [code]feedback[/code], [code]player[/code], [code]position[/code],
## [code]intensity[/code], [code]reversed[/code], [code]timescale_mode[/code], and the range
## keys read by [method Juice.get_range_multiplier]. Returns how many listeners
## received it.
func broadcast(event: StringName, extra: Dictionary = {}) -> int:
	var payload: Dictionary = {
		"feedback": self,
		"player": player,
		"position": _position,
		"intensity": _intensity,
		"reversed": _reversed,
		"timescale_mode": get_effective_timescale_mode(),
		"use_range": use_range,
		"range_distance": range_distance,
		"use_range_falloff": use_range_falloff,
		"range_falloff": range_falloff,
		"range_remap": remap_range_falloff,
	}
	payload.merge(extra, true)
	return Juice.broadcast(event, get_channel(), payload)


## The name shown in the editor.
func get_display_label() -> String:
	if not label.is_empty():
		return label
	return _get_display_label()


## The accessibility category of this feedback.
func get_category() -> StringName:
	return _get_category()


## The editor color of this feedback.
func get_color() -> Color:
	return _get_color()


## True when this feedback may play in the player's current direction.
func will_play_in_direction() -> bool:
	var backwards := player != null and player.direction == Juice.Direction.BACKWARD
	match direction_condition:
		Juice.DirectionCondition.ONLY_FORWARD:
			return not backwards
		Juice.DirectionCondition.ONLY_BACKWARD:
			return backwards
	return true


# --- Called by JuicePlayer -------------------------------------------------

## Prepares this runtime copy. Called by the player, not by user code.
func initialize(owner_player: JuicePlayer, index: int) -> void:
	player = owner_player
	_index = index
	_state = _State.IDLE
	_timer = 0.0
	_cooldown_left = 0.0
	_play_count = 0
	_session_started = false
	_no_more_repeats = false
	_plays_left = repeats + 1
	_target_cache = null
	_random_duration = 1.0
	_initialized = true
	_on_initialize()


## Starts this feedback. Returns true when it started or is waiting for its delay.
## False means a condition blocked it: inactive, wrong direction, cooldown, chance,
## play limit or intensity interval.
func play(play_position: Vector3 = Vector3.ZERO, incoming_intensity: float = 1.0) -> bool:
	if not active or player == null or not _initialized:
		return false
	if not will_play_in_direction() or _cooldown_left > 0.0:
		return false
	if chance <= 0.0 or (chance < 100.0 and randf() * 100.0 > chance):
		return false
	if limit_play_count and _play_count >= max_play_count:
		return false
	if use_intensity_interval and (incoming_intensity < intensity_min or incoming_intensity >= intensity_max):
		return false
	_incoming_intensity = incoming_intensity
	_position = play_position
	_no_more_repeats = false
	var delay := apply_time_multiplier(initial_delay) + _quantize_delay()
	if delay > 0.0:
		_state = _State.DELAY
		_timer = delay
		return true
	_start_plays()
	return true


## Moves this feedback forward in time. [param scaled_delta] and [param unscaled_delta]
## are the frame times; the feedback picks the one for its timescale mode.
func advance(scaled_delta: float, unscaled_delta: float) -> void:
	var dt := unscaled_delta if get_effective_timescale_mode() == Juice.TimeMode.UNSCALED else scaled_delta
	_delta = dt
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - dt)
	var left := dt
	var guard := 0
	while guard < 64:
		guard += 1
		match _state:
			_State.IDLE:
				return
			_State.DELAY:
				if _timer > left + _EPSILON:
					_timer -= left
					return
				left = maxf(0.0, left - _timer)
				_timer = 0.0
				_start_plays()
			_State.REPEAT_WAIT:
				if _timer > left + _EPSILON:
					_timer -= left
					return
				left = maxf(0.0, left - _timer)
				_timer = 0.0
				var zero_length := _run_duration <= 0.0001 and apply_time_multiplier(delay_between_repeats) <= 0.0001
				_trigger()
				if zero_length:
					return
			_State.RUNNING:
				var remaining := _run_duration - _elapsed
				if remaining > left + _EPSILON:
					_elapsed += left
					_on_progress(_directed(_elapsed / _run_duration))
					_on_tick()
					return
				left = maxf(0.0, left - remaining)
				_elapsed = _run_duration
				_on_progress(_directed(1.0))
				_on_tick()
				_finish_run()


## Stops this feedback. Pending delays and repeats are cancelled. A running play is
## interrupted when [member interrupts_on_stop] is true, and lets finish otherwise.
func stop() -> void:
	if _state == _State.DELAY or _state == _State.REPEAT_WAIT:
		_end_session()
	elif _state == _State.RUNNING and not interrupts_on_stop:
		_no_more_repeats = true
	elif _state == _State.RUNNING:
		_end_session()
	_plays_left = repeats + 1
	_cooldown_left = 0.0
	if interrupts_on_stop and _initialized:
		_on_stop()


## Jumps to the end of the current play without waiting. Repeats are dropped.
func skip_to_end() -> void:
	if _state == _State.DELAY:
		_timer = 0.0
		_start_plays()
	if _state == _State.REPEAT_WAIT:
		_end_session()
		return
	if _state != _State.RUNNING:
		return
	if _run_duration > 0.0:
		_elapsed = _run_duration
		_on_progress(_directed(1.0))
	_on_skip_to_end()
	_no_more_repeats = true
	_finish_run()


## Puts the target back the way it was found at initialization.
func restore() -> void:
	if _initialized:
		_on_restore()


## Called by the player when it is freed. Lets a busy feedback clean up.
func on_player_freed() -> void:
	if _initialized and _state != _State.IDLE:
		_end_session()
		_on_released()


## Called when the player starts a new play.
func reset_feedback() -> void:
	_plays_left = repeats + 1
	if reset_play_count_on_reset:
		_play_count = 0
	if _initialized:
		_on_reset()


## Clears the cooldown so the feedback can play at once.
func reset_cooldown() -> void:
	_cooldown_left = 0.0


## Rolls a new random duration multiplier. The player calls it at the start of each play.
func roll_random_duration() -> void:
	_random_duration = 1.0
	if randomize_duration:
		_random_duration = randf_range(random_duration_multiplier.x, random_duration_multiplier.y)


## Called when the sequence finishes.
func player_complete() -> void:
	if _initialized:
		_on_player_complete()


## Counts down the cooldown after the player slept for [param unscaled_seconds].
func wake(scaled_seconds: float, unscaled_seconds: float) -> void:
	var elapsed := unscaled_seconds if get_effective_timescale_mode() == Juice.TimeMode.UNSCALED else scaled_seconds
	_cooldown_left = maxf(0.0, _cooldown_left - elapsed)


# --- Internals -------------------------------------------------------------

func _apply_multiplier(seconds: float, source: JuicePlayer) -> float:
	var result := seconds
	if randomize_duration:
		result *= _random_duration
	if source != null:
		result = source.apply_time_multiplier(result)
	return result


func _directed(t: float) -> float:
	return 1.0 - t if _reversed else t


func _normal_direction() -> bool:
	var backwards := player != null and player.direction == Juice.Direction.BACKWARD
	match play_direction:
		Juice.PlayDirection.OPPOSITE_OF_PLAYER:
			return backwards
		Juice.PlayDirection.ALWAYS_FORWARD:
			return true
		Juice.PlayDirection.ALWAYS_BACKWARD:
			return false
	return not backwards


func _quantize_delay() -> float:
	if not quantize_to_bpm or bpm <= 0.0:
		return 0.0
	var grid := 60.0 / bpm * quantize_beats
	var into := fmod(Juice.unscaled_time(), grid)
	if into < 0.0005 or grid - into < 0.0005:
		return 0.0
	return grid - into


func _compute_intensity() -> float:
	var result := 1.0 if constant_intensity else _incoming_intensity
	if randomize_output:
		result *= randf_range(random_multiplier.x, random_multiplier.y)
	result *= player.compute_range_multiplier(_position)
	result *= Juice.get_multiplier(get_category())
	return result


func _start_plays() -> void:
	_plays_left = repeats + 1
	_trigger()


func _trigger() -> void:
	_plays_left -= 1
	_play_count += 1
	_cooldown_left = cooldown
	_retrigger_flag = _session_started
	_session_started = true
	_reversed = not _normal_direction()
	_intensity = _compute_intensity()
	_run_duration = get_feedback_duration()
	_elapsed = 0.0
	_state = _State.RUNNING
	_on_play(_intensity)
	if _state != _State.RUNNING:
		return
	if _run_duration > 0.0:
		_on_progress(_directed(0.0))
	else:
		_finish_run()


func _finish_run() -> void:
	_state = _State.IDLE
	_on_finished()
	if _state != _State.IDLE:
		return
	if not _no_more_repeats and (repeat_forever or _plays_left > 0):
		_state = _State.REPEAT_WAIT
		_timer = apply_time_multiplier(delay_between_repeats)
		return
	_end_session()


func _end_session() -> void:
	_state = _State.IDLE
	_session_started = false
	_retrigger_flag = false
	_no_more_repeats = false
	_plays_left = repeats + 1
