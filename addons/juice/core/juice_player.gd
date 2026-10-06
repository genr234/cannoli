@tool
@icon("res://addons/juice/icons/player.svg")
class_name JuicePlayer
extends Node
## Plays a list of [JuiceFeedback]s in sequence, forward or in reverse.
##
## Add it as a child of the node you want to affect, fill [member feedbacks] in the
## inspector, and call [method play]. Feedbacks start together unless the list holds
## pauses, holding pauses or loopers, which make the player walk the list top to bottom
## and wait where they say so.
##
## The player runs its own clock instead of using coroutines, so it can play in
## reverse, skip to the end and restore initial values at any moment. It duplicates
## the feedbacks when it initializes, so a feedback saved as a preset never shares
## state between players. In the editor it plays too, and puts everything back when
## the preview ends.

## Emitted when a play starts.
signal started
## Emitted when a play ends by itself.
signal finished
## Emitted when [method stop] ends a play.
signal stopped
## Emitted when the sequence waits, for [method pause] or for a pause feedback.
signal paused
## Emitted when the sequence continues after a pause.
signal resumed
## Emitted when the direction flips. [param backwards] is true when it now plays backwards.
signal reverted(backwards: bool)
## Emitted each time a looper sends the sequence back.
signal loop(looper: JuiceFeedback)
## Emitted after [method restore_initial_values].
signal restored
## Emitted by a [JuiceSignal] feedback. [param id] is the id set on that feedback.
signal triggered(id: StringName)
## Emitted after the runtime feedbacks were built.
signal initialized

enum _Wait { NONE, INITIAL_DELAY, HOLD, PAUSE, SCRIPT_PAUSE, LOOP_FLUSH, END }

const _MIN_MULTIPLIER := 0.0001
const _EPSILON := 0.000001

@export_group("Initialization")
## When the runtime feedbacks are built. MANUAL waits for [method initialize].
@export var initialization_mode: Juice.InitializationMode = Juice.InitializationMode.ON_READY
## Builds the feedbacks on the first play if that has not happened yet.
@export var auto_initialize: bool = true
## Plays once when the node is ready.
@export var auto_play_on_ready: bool = false
## Plays when the node is ready and each time it enters the tree again.
@export var auto_play_on_enable: bool = false
## When false, the player keeps running while the scene tree is paused.
@export var respect_tree_pause: bool = false

@export_group("Playback")
## The direction the list is walked. Feedbacks read it for their own play direction.
@export var direction: Juice.Direction = Juice.Direction.FORWARD
## Flips the direction each time a play ends.
@export var auto_flip_direction_on_end: bool = false
## When false, [method play] does nothing.
@export var can_play: bool = true
## When false, [method play] is ignored while a play is running.
@export var can_play_while_playing: bool = true
## The odds, in percent, that a call to [method play] starts.
@export_range(0.0, 100.0, 0.1) var chance_to_play: float = 100.0
## The default intensity. It is multiplied by the intensity passed to [method play].
@export_range(0.0, 10.0, 0.01, "or_greater") var intensity: float = 1.0
## Seconds after a start before another start is allowed.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var cooldown: float = 0.0
## Seconds to wait after a start before the first feedback plays.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var initial_delay: float = 0.0

@export_group("Time")
## The clock the player's own waits use. Unscaled keeps pauses running during hit stop.
@export var timescale_mode: Juice.TimeMode = Juice.TimeMode.UNSCALED
## Makes every feedback use [member forced_timescale_mode] instead of its own setting.
@export var force_timescale_mode: bool = false
## The mode used when [member force_timescale_mode] is on.
@export var forced_timescale_mode: Juice.TimeMode = Juice.TimeMode.UNSCALED
## Multiplies every duration, delay and pause.
@export_range(0.01, 10.0, 0.01, "or_greater") var duration_multiplier: float = 1.0
## Plays everything faster above 1 and slower below 1.
@export_range(0.01, 10.0, 0.01, "or_greater") var timescale_multiplier: float = 1.0
## Multiplies all durations by a random value each play.
@export var randomize_duration: bool = false
## The random multiplier range, x is the minimum and y the maximum.
@export var random_duration_multiplier: Vector2 = Vector2(0.5, 1.5)
## When true the player does not tick by itself. Call [method advance] instead.
@export var manual_update: bool = false

@export_group("Range")
## Plays only when the play position is close enough to the range center.
@export var only_play_if_within_range: bool = false
## The node that marks the center of the range, relative to this player.
@export var range_center: NodePath = NodePath()
## How far from the center plays are allowed, in world units.
@export var range_distance: float = 5.0
## Weakens the intensity with distance.
@export var use_range_falloff: bool = false
## The falloff over 0..1 of the distance. Null is a straight line from 1 to 0.
@export var range_falloff: Curve
## Maps the falloff curve's 0 and 1 to these values.
@export var remap_range_falloff: Vector2 = Vector2(0.0, 1.0)
## When true, [method Juice.set_range_center] does not change the center.
@export var ignore_range_events: bool = false

@export_group("Lifecycle")
## Stops the player when it leaves the tree.
@export var stop_on_exit_tree: bool = false
## Restores initial values when it leaves the tree.
@export var restore_on_exit_tree: bool = false

@export_group("Feedbacks")
## The feedbacks to play. The player plays duplicates, never these resources.
@export var feedbacks: Array[JuiceFeedback] = []

@export_group("Preview")
## Plays the feedbacks in the editor. Values are restored when the play ends.
@export_tool_button("Play", "Play") var preview_play_button: Callable = preview_play
## Stops the preview and restores the values.
@export_tool_button("Stop", "Stop") var preview_stop_button: Callable = preview_stop

var _runtime: Array[JuiceFeedback] = []
var _is_initialized := false
var _playing := false
var _user_paused := false
var _skipping := false
var _flip_pending := false
var _position := Vector3.ZERO
var _intensity := 1.0
var _elapsed := 0.0
var _since_mark := 0.0
var _hold_max := 0.0
var _head := 0
var _step := 1
var _wait: _Wait = _Wait.NONE
var _wait_time := 0.0
var _wait_target := 0.0
var _wait_feedback: JuiceFeedback
var _wait_played := true
var _cooldown_left := 0.0
var _random_multiplier := 1.0
var _play_count := 0
var _last_ticks := 0
var _sleep_ticks := 0
var _awake := false
var _ready_done := false
var _range_center_node: Node
var _ended_naturally := false

signal _ended


func _init() -> void:
	set_process(false)


func _enter_tree() -> void:
	if EngineDebugger.is_active():
		JuiceDebugRuntime.track(self)
	# Never in the editor, where the changed process_mode would be saved into the scene.
	if Engine.is_editor_hint():
		return
	if not respect_tree_pause and process_mode == Node.PROCESS_MODE_INHERIT:
		process_mode = Node.PROCESS_MODE_ALWAYS
	if only_play_if_within_range and not ignore_range_events:
		Juice.listen(Juice.EVENT_RANGE_CENTER, null, _on_range_center_event)
	if initialization_mode == Juice.InitializationMode.ON_ENTER_TREE:
		initialize()
	if _ready_done and auto_play_on_enable:
		play()


func _ready() -> void:
	_ready_done = true
	if Engine.is_editor_hint():
		return
	if initialization_mode == Juice.InitializationMode.ON_READY:
		initialize()
	if auto_play_on_ready or auto_play_on_enable:
		play()


func _exit_tree() -> void:
	Juice.unlisten(Juice.EVENT_RANGE_CENTER, _on_range_center_event)
	if stop_on_exit_tree or Engine.is_editor_hint():
		stop()
	if restore_on_exit_tree:
		restore_initial_values()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for fb in _runtime:
			fb.on_player_freed()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var unscaled := float(now - _last_ticks) * 0.000001
	_last_ticks = now
	advance(delta, unscaled)


# --- Initialization --------------------------------------------------------

## Builds the runtime copies of [member feedbacks]. Does nothing while playing
## unless [param force] is true. Call it again after changing the feedback list or
## whenever the targets moved and their initial values should be captured again.
func initialize(force: bool = false) -> void:
	if _playing and not force:
		return
	if _playing:
		stop()
	# In the editor, setting up a feedback can touch its target (a duplicated material,
	# hidden text). Undo that before the old copies are dropped, or it is saved in the scene.
	if Engine.is_editor_hint() and _is_initialized:
		for i in range(_runtime.size() - 1, -1, -1):
			_runtime[i].restore()
	_runtime.clear()
	for source in feedbacks:
		if source == null:
			continue
		var copy := source.duplicate() as JuiceFeedback
		_runtime.append(copy)
	for i in _runtime.size():
		_runtime[i].initialize(self, i)
	_cooldown_left = 0.0
	_is_initialized = true
	initialized.emit()


## True once [method initialize] has run.
func is_initialized() -> bool:
	return _is_initialized


# --- Playing ---------------------------------------------------------------

## Starts a play. [param position] is where the feedback happens, used for range and
## by shakers. It can be a Vector3, a Vector2, a node or null. Null uses the parent's
## position. [param intensity_scale] multiplies [member intensity]. Returns false when
## nothing started: disabled, cooling down, out of range, or the chance roll failed.
func play(position: Variant = null, intensity_scale: float = 1.0) -> bool:
	return _play(position, intensity_scale, false)


## Starts a play after flipping the direction, so a list that normally goes forward
## goes backward. The direction stays flipped afterwards.
func play_reversed(position: Variant = null, intensity_scale: float = 1.0) -> bool:
	return _play(position, intensity_scale, true)


func _play(position: Variant, intensity_scale: float, flip: bool) -> bool:
	var play_position := Juice.to_vector3(position, _own_position())
	# Cooldowns are only counted down while awake, so catch up on the idle time first.
	_catch_up_cooldowns()
	if not _is_allowed(play_position):
		return false
	if flip:
		flip_direction()
	if Engine.is_editor_hint() and not _playing:
		initialize(true)
	elif not _is_initialized:
		if not auto_initialize:
			push_warning("JuicePlayer '%s' was played before initialize() was called." % name)
			return false
		initialize()
	_wake()
	_skipping = false
	_user_paused = false
	if _flip_pending:
		_flip_pending = false
		_set_direction(Juice.Direction.BACKWARD if direction == Juice.Direction.FORWARD else Juice.Direction.FORWARD)
	for fb in _runtime:
		if fb.active:
			fb.reset_feedback()
	_random_multiplier = 1.0
	if randomize_duration:
		_random_multiplier = randf_range(random_duration_multiplier.x, random_duration_multiplier.y)
	for fb in _runtime:
		fb.roll_random_duration()
	_position = play_position
	_intensity = intensity * intensity_scale
	_elapsed = 0.0
	_since_mark = 0.0
	_hold_max = 0.0
	_wait = _Wait.NONE
	_play_count += 1
	_cooldown_left = cooldown
	_playing = true
	started.emit()
	var delay := apply_time_multiplier(initial_delay)
	if delay > 0.0:
		_wait = _Wait.INITIAL_DELAY
		_wait_time = 0.0
		_wait_target = delay
	else:
		_begin_sequence()
	_pump()
	return true


## Starts a play and waits until it ends. Returns true when it ended by itself and
## false when it was stopped or never started. Use it as [code]await player.play_async()[/code].
func play_async(position: Variant = null, intensity_scale: float = 1.0) -> bool:
	if not play(position, intensity_scale):
		return false
	if not _playing:
		return true
	await _ended
	return _ended_naturally


## Ends the play and, by default, stops every feedback. Pass false to only stop the
## sequence from going on while running feedbacks finish by themselves.
func stop(stop_feedbacks: bool = true) -> void:
	var was_playing := _playing
	_playing = false
	_wait = _Wait.NONE
	_user_paused = false
	if stop_feedbacks:
		for fb in _runtime:
			fb.stop()
	if was_playing:
		_ended_naturally = false
		stopped.emit()
		_ended.emit()
	if Engine.is_editor_hint():
		restore_initial_values()


## Holds the sequence where it is. Feedbacks that already started keep running.
func pause() -> void:
	if not _playing or _user_paused:
		return
	_user_paused = true
	paused.emit()


## Continues a sequence held by [method pause] or by a script driven pause feedback.
func resume() -> void:
	if not _user_paused:
		return
	_user_paused = false
	if _wait != _Wait.SCRIPT_PAUSE:
		resumed.emit()
	_pump()


## Finishes the play at once. Feedbacks jump to their final state, waits and loops are skipped.
func skip_to_end() -> void:
	if not _playing and not _any_busy():
		return
	_skipping = true
	_user_paused = false
	match _wait:
		_Wait.INITIAL_DELAY:
			_begin_sequence()
		_Wait.PAUSE, _Wait.SCRIPT_PAUSE:
			if _wait_feedback != null:
				_complete_step(_wait_feedback, _wait_played)
		_Wait.LOOP_FLUSH:
			_head += _step
	_wait = _Wait.NONE
	_run_head()
	for fb in _runtime:
		if fb.active:
			fb.skip_to_end()
	_skipping = false
	if _playing:
		_finish()


## Puts every target back to the values captured at initialization. It also stops
## running feedbacks. Does nothing if the player never played.
func restore_initial_values() -> void:
	if not _is_initialized or _play_count <= 0:
		return
	var was_playing := _playing
	_playing = false
	_wait = _Wait.NONE
	_user_paused = false
	for fb in _runtime:
		fb.stop()
	for i in range(_runtime.size() - 1, -1, -1):
		if _runtime[i].active:
			_runtime[i].restore()
	if was_playing:
		_ended_naturally = false
		stopped.emit()
		_ended.emit()
	restored.emit()


## Clears the cooldown of the player and of every feedback.
func reset_cooldowns() -> void:
	_cooldown_left = 0.0
	for fb in _runtime:
		fb.reset_cooldown()


## Sets the direction. Emits [signal reverted] when it changed.
func set_direction(new_direction: Juice.Direction) -> void:
	_set_direction(new_direction)


## Flips between forward and backward.
func flip_direction() -> void:
	_set_direction(Juice.Direction.BACKWARD if direction == Juice.Direction.FORWARD else Juice.Direction.FORWARD)


## True while a play is running, including waits and pauses.
func is_playing() -> bool:
	return _playing


## True while the sequence is held by [method pause] or a script driven pause.
func is_paused() -> bool:
	return _user_paused


## Seconds since the last play started, on the player's clock. It keeps its value
## after the play ends until the next one starts.
func get_elapsed_time() -> float:
	return _elapsed


## How many times this player has started.
func get_play_count() -> int:
	return _play_count


## Moves the player forward in time. It is called by the engine unless
## [member manual_update] is on. [param scaled_delta] follows the time scale, and
## [param unscaled_delta] ignores it. A negative unscaled value reuses the scaled one.
func advance(scaled_delta: float, unscaled_delta: float = -1.0) -> void:
	if unscaled_delta < 0.0:
		unscaled_delta = scaled_delta
	var player_dt := unscaled_delta if _player_mode() == Juice.TimeMode.UNSCALED else scaled_delta
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - player_dt)
	for fb in _runtime:
		fb.advance(scaled_delta, unscaled_delta)
	if _playing:
		_elapsed += player_dt
		_since_mark += player_dt
		_wait_time += _wait_delta(scaled_delta, unscaled_delta)
		if _wait == _Wait.SCRIPT_PAUSE and _wait_target > 0.0 and _wait_time >= _wait_target - _EPSILON:
			_user_paused = false
		_pump()
	if not _playing and not _any_busy():
		_sleep()


# --- Feedback list ---------------------------------------------------------

## Adds a feedback. When the player is initialized, the added feedback is duplicated and
## initialized too. Returns the instance that will play, which is the runtime copy
## after initialization and [param feedback] itself before.
func add_feedback(feedback: JuiceFeedback) -> JuiceFeedback:
	feedbacks.append(feedback)
	if not _is_initialized:
		return feedback
	var copy := feedback.duplicate() as JuiceFeedback
	_runtime.append(copy)
	copy.initialize(self, _runtime.size() - 1)
	return copy


## Removes a feedback, either the resource in [member feedbacks] or its runtime copy.
func remove_feedback(feedback: JuiceFeedback) -> void:
	var runtime_index := _runtime.find(feedback)
	if runtime_index >= 0:
		_runtime[runtime_index].stop()
		_runtime.remove_at(runtime_index)
		if runtime_index < feedbacks.size():
			feedbacks.remove_at(runtime_index)
		return
	var source_index := feedbacks.find(feedback)
	if source_index >= 0:
		feedbacks.remove_at(source_index)
		if _is_initialized and source_index < _runtime.size():
			_runtime[source_index].stop()
			_runtime.remove_at(source_index)


## The first feedback made from [param type], such as [code]JuiceScale[/code].
## Returns the runtime copy once initialized. [param nth] picks a later one.
func get_feedback_of_type(type: Script, nth: int = 0) -> JuiceFeedback:
	var found := 0
	for fb in _active_list():
		if fb != null and is_instance_of(fb, type):
			if found == nth:
				return fb
			found += 1
	return null


## Every feedback made from [param type].
func get_feedbacks_of_type(type: Script) -> Array[JuiceFeedback]:
	var result: Array[JuiceFeedback] = []
	for fb in _active_list():
		if fb != null and is_instance_of(fb, type):
			result.append(fb)
	return result


## The first feedback whose displayed label equals [param feedback_label].
func get_feedback_by_label(feedback_label: String) -> JuiceFeedback:
	for fb in _active_list():
		if fb != null and fb.get_display_label() == feedback_label:
			return fb
	return null


## The feedbacks that would play: the runtime copies once initialized, the resources before.
func get_feedbacks() -> Array[JuiceFeedback]:
	return _active_list()


## How long a play takes from start to finish on the player's clock, in seconds. It walks the list
## the way a play does and counts the initial delay, feedback delays, repeats, pauses
## and loops. A repeat forever or an infinite loop counts once, see [method has_endless_feedback].
func get_total_duration() -> float:
	var list := _active_list()
	var count := list.size()
	var step := 1 if direction == Juice.Direction.FORWARD else -1
	var head := 0 if step > 0 else count - 1
	var time := 0.0
	var mark := 0.0
	var hold := 0.0
	var latest := 0.0
	var passes: Dictionary[int, int] = {}
	var guard := 0
	while head >= 0 and head < count and guard < 4096:
		guard += 1
		var fb := list[head]
		if fb == null or not fb.active or not fb.will_play_in_direction():
			head += step
			continue
		if fb._is_holding_pause() or fb._is_looper():
			time = maxf(time, mark + hold)
			hold = 0.0
			mark = time
		var duration := fb.compute_total_duration(self)
		latest = maxf(latest, time + duration)
		if fb._is_pause():
			if fb._is_script_driven_pause():
				time += fb._get_auto_resume()
			else:
				time += fb.get_pause_duration(self)
			latest = maxf(latest, time)
			mark = time
			hold = 0.0
		elif not fb.exclude_from_holding_pauses:
			hold = maxf(hold, duration)
		if fb._is_looper():
			var left: int = passes.get(head, fb._get_loop_count()) - 1
			passes[head] = left
			if left > 0:
				time = maxf(time, latest)
				mark = time
				hold = 0.0
				head = _find_loop_resume_index(list, head, step, fb)
				continue
		head += step
	return apply_time_multiplier(initial_delay) + maxf(time, latest)


## True when a feedback repeats forever or a looper never ends, so a play never finishes by itself.
func has_endless_feedback() -> bool:
	for fb in _active_list():
		if fb == null or not fb.active:
			continue
		if fb.repeat_forever:
			return true
		if fb._is_looper() and fb._get_loop_count() <= 0:
			return true
	return false


## Applies the player's duration and timescale multipliers to [param seconds].
func apply_time_multiplier(seconds: float) -> float:
	return seconds * maxf(duration_multiplier, _MIN_MULTIPLIER) * _random_multiplier / maxf(timescale_multiplier, _MIN_MULTIPLIER)


## How strongly a play at [param at_position] should be felt, from 0 to 1 and beyond with a remap.
## Always 1 when [member only_play_if_within_range] is off.
func compute_range_multiplier(at_position: Vector3) -> float:
	if not only_play_if_within_range:
		return 1.0
	var center := _get_range_center()
	if center == null:
		return 0.0
	var distance := Juice.node_position(center).distance_to(at_position)
	return Juice.range_falloff_value(distance, range_distance, use_range_falloff, range_falloff, remap_range_falloff)


## Sets the range center node at runtime.
func set_range_center(center: Node) -> void:
	_range_center_node = center


## Plays in the editor preview. Does nothing at runtime.
func preview_play() -> void:
	if Engine.is_editor_hint():
		play()


## Stops the editor preview and restores the values.
func preview_stop() -> void:
	if Engine.is_editor_hint():
		stop()
		restore_initial_values()


# --- Sequencer -------------------------------------------------------------

func _active_list() -> Array[JuiceFeedback]:
	# An idle editor player plans from the exported list, so edits show at once.
	if _is_initialized and (_playing or not Engine.is_editor_hint()):
		return _runtime
	var list: Array[JuiceFeedback] = []
	for fb in feedbacks:
		if fb != null:
			list.append(fb)
	return list


func _player_mode() -> Juice.TimeMode:
	return forced_timescale_mode if force_timescale_mode else timescale_mode


func _wait_delta(scaled_delta: float, unscaled_delta: float) -> float:
	var mode := _player_mode()
	if (_wait == _Wait.PAUSE or _wait == _Wait.SCRIPT_PAUSE) and _wait_feedback != null:
		mode = _wait_feedback.get_effective_timescale_mode()
	return unscaled_delta if mode == Juice.TimeMode.UNSCALED else scaled_delta


func _own_position() -> Vector3:
	return Juice.node_position(get_parent())


func _is_allowed(at_position: Vector3) -> bool:
	if not can_play or not is_inside_tree() or not Juice.is_enabled():
		return false
	if _playing and not can_play_while_playing:
		return false
	if chance_to_play <= 0.0 or (chance_to_play < 100.0 and randf() * 100.0 > chance_to_play):
		return false
	if _cooldown_left > 0.0 and _is_initialized:
		return false
	if only_play_if_within_range:
		var center := _get_range_center()
		if center == null or Juice.node_position(center).distance_to(at_position) > range_distance:
			return false
	return true


func _get_range_center() -> Node:
	if is_instance_valid(_range_center_node):
		return _range_center_node
	if range_center.is_empty():
		return null
	return get_node_or_null(range_center)


func _on_range_center_event(payload: Dictionary) -> void:
	if only_play_if_within_range and not ignore_range_events:
		_range_center_node = payload.get("center", null)


func _set_direction(new_direction: Juice.Direction) -> void:
	if direction == new_direction:
		return
	direction = new_direction
	reverted.emit(direction == Juice.Direction.BACKWARD)


func _wake() -> void:
	if _awake:
		return
	_awake = true
	_catch_up_cooldowns()
	_last_ticks = Time.get_ticks_usec()
	if not manual_update:
		set_process(true)


func _catch_up_cooldowns() -> void:
	# With manual updates, advance() keeps counting cooldowns down while asleep.
	if _awake or _sleep_ticks <= 0 or manual_update:
		return
	var now := Time.get_ticks_usec()
	var idle := float(now - _sleep_ticks) * 0.000001
	_sleep_ticks = now
	_cooldown_left = maxf(0.0, _cooldown_left - idle)
	for fb in _runtime:
		fb.wake(idle * Engine.time_scale, idle)


func _sleep() -> void:
	if not _awake:
		return
	_awake = false
	_sleep_ticks = Time.get_ticks_usec()
	set_process(false)


func _any_busy() -> bool:
	for fb in _runtime:
		if fb.is_busy():
			return true
	return false


func _has_blocking() -> bool:
	for fb in _runtime:
		if fb.active and fb.blocks_player():
			return true
	return false


func _begin_sequence() -> void:
	_step = 1 if direction == Juice.Direction.FORWARD else -1
	_head = 0 if _step > 0 else _runtime.size() - 1
	_hold_max = 0.0
	_since_mark = 0.0
	_wait = _Wait.NONE


# Runs the head and resolves waits until something has to wait for real time.
func _pump() -> void:
	var guard := 0
	while _playing and not _user_paused and guard < 4096:
		guard += 1
		if _wait == _Wait.NONE:
			_run_head()
			if _wait == _Wait.NONE or not _playing:
				return
		if not _wait_is_over():
			return
		_leave_wait()


func _wait_is_over() -> bool:
	match _wait:
		_Wait.INITIAL_DELAY, _Wait.PAUSE:
			return _wait_time >= _wait_target - _EPSILON
		_Wait.HOLD:
			return _since_mark >= _hold_max - _EPSILON
		_Wait.SCRIPT_PAUSE:
			return not _user_paused
		_Wait.LOOP_FLUSH, _Wait.END:
			return not _has_blocking()
	return true


func _leave_wait() -> void:
	var finished_wait := _wait
	_wait = _Wait.NONE
	match finished_wait:
		_Wait.INITIAL_DELAY:
			_begin_sequence()
		_Wait.PAUSE, _Wait.SCRIPT_PAUSE:
			_since_mark = 0.0
			_hold_max = 0.0
			resumed.emit()
			_complete_step(_wait_feedback, _wait_played)
		_Wait.LOOP_FLUSH:
			_do_loop_jump(_wait_feedback)
		_Wait.END:
			_finish()


func _run_head() -> void:
	var guard := 0
	while _playing and _wait == _Wait.NONE and not _user_paused and guard < 4096:
		guard += 1
		if _head < 0 or _head >= _runtime.size():
			_wait = _Wait.END
			return
		var fb := _runtime[_head]
		var counts := fb.active and fb.will_play_in_direction()
		if counts and (fb._is_holding_pause() or fb._is_looper()) and not _skipping:
			if _since_mark < _hold_max - _EPSILON:
				_wait = _Wait.HOLD
				return
			_hold_max = 0.0
			_since_mark = 0.0
		var played := fb.play(_position, _intensity)
		if counts and played and fb._is_pause() and not _skipping and _begin_pause(fb):
			return
		_complete_step(fb, played)


func _begin_pause(fb: JuiceFeedback) -> bool:
	_wait_feedback = fb
	_wait_played = true
	_wait_time = 0.0
	if fb._is_script_driven_pause():
		_wait = _Wait.SCRIPT_PAUSE
		_wait_target = fb._get_auto_resume()
		_user_paused = true
		paused.emit()
		return true
	_wait_target = fb.get_pause_duration()
	if _wait_target <= 0.0:
		return false
	_wait = _Wait.PAUSE
	paused.emit()
	return true


func _complete_step(fb: JuiceFeedback, played: bool) -> void:
	var counts := fb.active and fb.will_play_in_direction()
	if counts and not fb._is_pause() and not fb.exclude_from_holding_pauses:
		_hold_max = maxf(_hold_max, fb.compute_total_duration(self))
	if counts and played and fb._is_looper() and not _skipping and fb._is_loop_pending():
		_wait = _Wait.LOOP_FLUSH
		_wait_feedback = fb
		return
	_head += _step


func _do_loop_jump(looper: JuiceFeedback) -> void:
	_head = _find_loop_resume_index(_runtime, _head, _step, looper)
	_hold_max = 0.0
	_since_mark = 0.0
	loop.emit(looper)


# The index to continue at after a looper at [param from]. It is the feedback after
# the nearest earlier pause or looper start the looper accepts, or the start of the list.
func _find_loop_resume_index(list: Array[JuiceFeedback], from: int, step: int, looper: JuiceFeedback) -> int:
	var j := from - step
	while j >= 0 and j < list.size():
		var fb := list[j]
		if fb != null and fb.active and fb.will_play_in_direction():
			if looper._loops_to_last_pause() and fb._is_pause() and fb.get_pause_duration(self) > 0.0:
				return j + step
			if looper._loops_to_last_looper_start() and fb._is_looper_start():
				return j + step
		j -= step
	return 0 if step > 0 else list.size() - 1


func _finish() -> void:
	_playing = false
	_wait = _Wait.NONE
	for fb in _runtime:
		if fb.active:
			fb.player_complete()
	if auto_flip_direction_on_end:
		_flip_pending = true
	_ended_naturally = true
	finished.emit()
	_ended.emit()
	if Engine.is_editor_hint():
		restore_initial_values()
