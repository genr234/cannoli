@tool
@icon("res://addons/juice/icons/sequencer.svg")
class_name JuiceInputSequenceRecorder
extends Node
## Records a [JuiceSequence] by playing it: press the input actions of the tracks.
##
## Each [JuiceSequenceTrack] has an input action. While recording, pressing that action
## adds a note to the track. When recording stops the notes are quantized to the grid of the
## sequence (see [method JuiceSequence.quantize_raw]).
##
## Two ways to record:
## [br]- Free: notes are timed from the start of the recording and quantized at the end.
## [br]- Live: set [member sequencer] and play it. Notes land directly on the nearest step of
## the pattern that is playing, so you can build a loop by hearing it.
##
## [member toggle_action] starts and stops recording from the keyboard, if set.

## Emitted when recording starts.
signal recording_started
## Emitted when recording stops, after quantizing.
signal recording_stopped
## Emitted for every note: the track index and its time in seconds, or its step when live.
signal note_recorded(track_index: int, time: float, step_index: int)

@export_group("Target")
## The sequence to record into.
@export var sequence: JuiceSequence
## A sequencer that plays while recording. When it is playing, notes go straight to its grid.
@export var sequencer: NodePath

@export_group("Recording")
## Starts recording when the node is ready.
@export var record_on_ready: bool = false
## Starts the clock at the first note, so waiting before it does not count.
@export var remove_initial_silence: bool = true
## Keeps the notes already recorded instead of clearing them when recording starts.
@export var additive: bool = false
## Moves every note by this many seconds. Useful to cancel input latency.
@export_range(-1.0, 1.0, 0.001, "suffix:s") var start_offset: float = 0.0
## Quantizes to the grid when recording stops.
@export var quantize_on_stop: bool = true
## An input action that starts and stops recording. Empty has none.
@export var toggle_action: StringName = &""
## Which clock times the notes.
@export var time_mode: Juice.TimeMode = Juice.TimeMode.UNSCALED

## True while recording.
var recording: bool = false

var _clock := 0.0
var _started_at := 0.0
var _live_used := false


func _ready() -> void:
	set_process(false)
	set_process_input(false)
	if Engine.is_editor_hint():
		return
	set_process_input(true)
	if record_on_ready:
		start_recording()


func _process(delta: float) -> void:
	_clock += delta


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if toggle_action != &"" and InputMap.has_action(toggle_action) and event.is_action_pressed(toggle_action):
		if recording:
			stop_recording()
		else:
			start_recording()
		return
	if not recording or sequence == null:
		return
	for index in sequence.tracks.size():
		var track := sequence.tracks[index]
		if track == null or not track.active or track.action == &"" or not InputMap.has_action(track.action):
			continue
		if event.is_action_pressed(track.action):
			record_note(index)


# --- Public API ------------------------------------------------------------

## Starts recording. Clears the recorded notes unless [member additive] is on.
func start_recording() -> void:
	if sequence == null:
		push_warning("JuiceInputSequenceRecorder '%s' needs a sequence to record into." % name)
		return
	if not additive:
		sequence.clear_raw_notes()
	_clock = 0.0
	_started_at = _now()
	_live_used = false
	recording = true
	set_process(time_mode == Juice.TimeMode.SCALED)
	recording_started.emit()


## Stops recording and quantizes the notes if [member quantize_on_stop] is on.
func stop_recording() -> void:
	if not recording:
		return
	recording = false
	set_process(false)
	if quantize_on_stop and not _live_used:
		sequence.quantize_raw()
	recording_stopped.emit()


## Adds a note on a track now, as if its action was pressed.
func record_note(track_index: int) -> void:
	if sequence == null or track_index < 0 or track_index >= sequence.tracks.size():
		return
	var live := _get_live_sequencer()
	if live != null:
		var step_index := live.get_nearest_step()
		sequence.set_step(track_index, step_index, true)
		_live_used = true
		note_recorded.emit(track_index, 0.0, step_index)
		return
	if sequence.raw_note_times.is_empty() and remove_initial_silence:
		_started_at = _now()
		_clock = 0.0
	var time := _now() - _started_at + start_offset
	sequence.add_raw_note(maxf(time, 0.0), sequence.tracks[track_index].id)
	note_recorded.emit(track_index, time, -1)


# --- Internals -------------------------------------------------------------

func _now() -> float:
	if time_mode == Juice.TimeMode.SCALED:
		return _clock
	return Juice.unscaled_time()


func _get_live_sequencer() -> JuiceSequencer:
	if sequencer.is_empty():
		return null
	var node := get_node_or_null(sequencer) as JuiceSequencer
	if node != null and node.playing:
		return node
	return null

