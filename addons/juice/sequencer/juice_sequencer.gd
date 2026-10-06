@tool
@icon("res://addons/juice/icons/sequencer.svg")
class_name JuiceSequencer
extends Node
## Plays a [JuiceSequence] like a step sequencer, firing something for every note.
##
## On every step the sequencer looks at each active track. When the track has a note on that
## step it:
## [br]- plays the [JuicePlayer] assigned to that track in [member track_players],
## [br]- plays the audio assigned in [member track_sounds], through a small pool of
## [AudioStreamPlayer]s so notes can overlap,
## [br]- emits [signal note].
## [br]Every step also emits [signal step], and the first step of each beat emits [signal beat].
## Use whichever you need; all three can be mixed.
##
## The tempo comes from the sequence, unless [member bpm_override] is set. Steps are timed
## by accumulating time, so they stay even whatever the frame rate, and a long frame fires
## the missed steps. The first step fires on the first update after [method play].
##
## Use [member time_mode] UNSCALED to keep the beat going when the game is slowed or
## paused by [member Engine.time_scale]. With [member manual_update] on, call [method advance]
## yourself.

## Emitted for every step, with its index.
signal step(step_index: int)
## Emitted on the first step of each beat, with the beat number counted from 0.
signal beat(beat_index: int)
## Emitted for every note that plays: the track index and the step.
signal note(track_index: int, step_index: int)
## Emitted when playback starts.
signal started
## Emitted when playback stops, by [method stop] or because a non-looping pattern ended.
signal stopped
## Emitted each time a looping pattern goes back to the start.
signal looped

@export_group("Sequence")
## The pattern to play.
@export var sequence: JuiceSequence
## A tempo to use instead of the sequence's. 0 uses the sequence's.
@export_range(0, 400, 1, "or_greater") var bpm_override: int = 0

@export_group("Playback")
## Starts playing when the node is ready.
@export var play_on_ready: bool = false
## Goes back to the start at the end of the pattern. When off, it stops there.
@export var loop: bool = true
## Plays the steps in random order.
@export var random_order: bool = false
## Which clock times the steps.
@export var time_mode: Juice.TimeMode = Juice.TimeMode.SCALED
## Do not advance by itself. Call [method advance].
@export var manual_update: bool = false

@export_group("Triggers")
## One [JuicePlayer] per track, in track order. Empty entries are skipped.
@export var track_players: Array[NodePath] = []
## One sound per track, in track order. Empty entries are skipped.
@export var track_sounds: Array[AudioStream] = []
## The bus the sounds play on.
@export var sound_bus: StringName = &"Master"
## The volume of the sounds.
@export_range(-80.0, 24.0, 0.1, "suffix:dB") var sound_volume_db: float = 0.0
## How many sounds can play at once. When all are busy the oldest is cut.
@export_range(1, 64, 1, "or_greater") var max_voices: int = 8

@export_group("Metronome")
## A click played on every beat. Empty is silent.
@export var metronome_sound: AudioStream
## The volume of the click.
@export_range(-80.0, 24.0, 0.1, "suffix:dB") var metronome_volume_db: float = -14.0

## True while the sequence plays.
var playing: bool = false
## The index of the step that fired last, or -1 before the first one.
var current_step: int = -1

var _countdown := 0.0
var _next_step := 0
var _last_usec := 0
var _voices: Array[AudioStreamPlayer] = []
var _voice_cursor := 0
var _metronome: AudioStreamPlayer
var _fired_once := false


func _ready() -> void:
	set_process(false)
	if Engine.is_editor_hint():
		return
	if play_on_ready:
		play()


func _process(delta: float) -> void:
	if manual_update:
		return
	var step_time := delta
	if time_mode == Juice.TimeMode.UNSCALED:
		var now := Time.get_ticks_usec()
		step_time = float(now - _last_usec) * 0.000001
		_last_usec = now
	advance(step_time)


# --- Public API ------------------------------------------------------------

## Starts from the first step. The first step fires on the next update.
func play() -> void:
	if sequence == null or sequence.tracks.is_empty():
		return
	sequence.ensure_grid()
	_countdown = 0.0
	_next_step = 0
	current_step = -1
	_fired_once = false
	_last_usec = Time.get_ticks_usec()
	playing = true
	set_process(not manual_update)
	started.emit()


## Stops playing.
func stop() -> void:
	if not playing:
		return
	playing = false
	set_process(false)
	stopped.emit()


## Plays when stopped, stops when playing.
func toggle() -> void:
	if playing:
		stop()
	else:
		play()


## Advances the clock by [param delta] seconds and fires the steps that came due.
func advance(delta: float) -> void:
	if not playing or sequence == null:
		return
	_countdown -= delta
	var guard := 0
	while playing and _countdown <= 0.0 and guard < 32:
		guard += 1
		_fire_step()
		_countdown += _get_step_duration()


## Fires the sound and player of a track right now, whatever the pattern says.
func trigger_track(track_index: int) -> void:
	if Engine.is_editor_hint():
		return
	_play_track(track_index)


## Mutes or unmutes a track.
func set_track_active(track_index: int, active: bool) -> void:
	if sequence != null and track_index >= 0 and track_index < sequence.tracks.size():
		sequence.tracks[track_index].active = active


## Flips a step on every track. See [method JuiceSequence.toggle_step].
func toggle_step(step_index: int) -> void:
	if sequence != null:
		sequence.toggle_step(step_index)


## Removes every note of the sequence.
func clear_pattern() -> void:
	if sequence != null:
		sequence.clear_grid()


## The step closest to the playback position right now. A recorder uses it to place a
## note on the grid while the pattern plays.
func get_nearest_step() -> int:
	if not playing or sequence == null or current_step < 0:
		return 0
	var steps := sequence.get_total_steps()
	var elapsed := _get_step_duration() - _countdown
	if elapsed > _get_step_duration() * 0.5:
		return (current_step + 1) % steps
	return current_step


## The seconds one step lasts, with the tempo override applied.
func get_step_duration() -> float:
	return _get_step_duration()


# --- Internals -------------------------------------------------------------

func _get_step_duration() -> float:
	if sequence == null:
		return 0.5
	if bpm_override > 0:
		return 60.0 / float(bpm_override) / float(maxi(sequence.steps_per_beat, 1))
	return sequence.get_step_duration()


@warning_ignore("integer_division")
func _fire_step() -> void:
	var steps := sequence.get_total_steps()
	var index := _next_step
	if _fired_once and index == 0 and not random_order:
		looped.emit()
	_fired_once = true
	current_step = index
	step.emit(index)
	if index % maxi(sequence.steps_per_beat, 1) == 0:
		beat.emit(index / maxi(sequence.steps_per_beat, 1))
		_play_metronome()
	for track_index in sequence.get_triggered_tracks(index):
		note.emit(track_index, index)
		_play_track(track_index)
	if random_order:
		_next_step = randi() % steps
	else:
		_next_step = index + 1
	if _next_step >= steps:
		if loop:
			_next_step = 0
		else:
			stop()


func _play_track(track_index: int) -> void:
	if track_index >= 0 and track_index < track_players.size() and not track_players[track_index].is_empty():
		var target := get_node_or_null(track_players[track_index]) as JuicePlayer
		if target != null:
			target.play()
	if track_index >= 0 and track_index < track_sounds.size() and track_sounds[track_index] != null:
		_play_sound(track_sounds[track_index], sound_volume_db)


func _play_metronome() -> void:
	if metronome_sound == null:
		return
	if _metronome == null:
		_metronome = AudioStreamPlayer.new()
		_metronome.name = "Metronome"
		add_child(_metronome)
	_metronome.stream = metronome_sound
	_metronome.bus = sound_bus
	_metronome.volume_db = metronome_volume_db
	_metronome.play()


func _play_sound(stream: AudioStream, volume_db: float) -> void:
	var voice := _get_voice()
	voice.stream = stream
	voice.bus = sound_bus
	voice.volume_db = volume_db
	voice.play()


# Idle voices first; when all are busy the next one in turn is cut.
func _get_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	if _voices.size() < max_voices:
		var created := AudioStreamPlayer.new()
		created.name = "Voice%d" % _voices.size()
		add_child(created)
		_voices.append(created)
		return created
	_voice_cursor = (_voice_cursor + 1) % _voices.size()
	return _voices[_voice_cursor]
