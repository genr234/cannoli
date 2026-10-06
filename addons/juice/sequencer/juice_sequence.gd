@tool
@icon("res://addons/juice/icons/sequencer.svg")
class_name JuiceSequence
extends Resource
## A pattern for a [JuiceSequencer]: tracks, a tempo and a grid of notes.
##
## The grid has one row per track and [member steps_per_beat] steps per beat for each of the
## [member length_beats] beats. A step is either on or off.
##
## You can fill the grid by hand, with [method set_step], or record raw notes (a time and a
## track id each) with [method add_raw_note] and let [method quantize_raw] snap them to the
## grid at the tempo of this sequence. [JuiceInputSequenceRecorder] does the recording.
##
## Resizing [member length_beats], [member steps_per_beat] or [member tracks] does not touch
## the grid until [method ensure_grid] runs (the sequencer calls it before playing).

## Colors handed out to new tracks.
const _TRACK_COLORS: Array[Color] = [
	Color("7fffd4"), Color("ff7f50"), Color("ffd700"), Color("00ffff"),
	Color("ff69b4"), Color("adff2f"), Color("c470ff"), Color("87ceeb"),
	Color("fa8072"), Color("40e0d0"), Color("daa520"), Color("98fb98"),
]

@export_group("Tempo")
## Beats per minute.
@export_range(20, 400, 1, "or_greater") var bpm: int = 120
## How many beats the pattern lasts.
@export_range(1, 64, 1, "or_greater") var length_beats: int = 8
## How many grid steps fit in one beat. 4 gives sixteenth notes.
@export_range(1, 16, 1, "or_greater") var steps_per_beat: int = 1
## Silence added after the last raw note when a recording is quantized, in seconds.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var end_silence: float = 0.0

@export_group("Tracks")
## The lanes of the pattern.
@export var tracks: Array[JuiceSequenceTrack] = []

@export_group("Notes")
## The grid. One packed array per track, with one byte per step: 0 is off, anything else is on.
@export var grid: Array[PackedByteArray] = []
## Times in seconds of recorded notes, before quantizing.
@export var raw_note_times: PackedFloat32Array = PackedFloat32Array()
## The track id of each recorded note, same order as [member raw_note_times].
@export var raw_note_tracks: PackedInt32Array = PackedInt32Array()

@export_group("Tools")
## Resizes the grid to match the tracks, length and steps per beat.
@export_tool_button("Resize Grid", "Reload") var resize_grid_button: Callable = ensure_grid
## Gives every track a new random color.
@export_tool_button("Randomize Colors", "Color") var randomize_colors_button: Callable = randomize_track_colors


# --- Time ------------------------------------------------------------------

## Seconds of one beat at the tempo of this sequence.
func get_beat_duration() -> float:
	return 60.0 / maxf(float(bpm), 1.0)


## Seconds of one grid step.
func get_step_duration() -> float:
	return get_beat_duration() / float(maxi(steps_per_beat, 1))


## How many steps the pattern has in total.
func get_total_steps() -> int:
	return maxi(length_beats, 1) * maxi(steps_per_beat, 1)


## Seconds the whole pattern lasts.
func get_duration() -> float:
	return get_total_steps() * get_step_duration()


# --- Grid ------------------------------------------------------------------

## Makes the grid match the tracks and the length, keeping notes that still fit.
func ensure_grid() -> void:
	var steps := get_total_steps()
	var rows: Array[PackedByteArray] = []
	for index in tracks.size():
		var row := PackedByteArray()
		if index < grid.size():
			row = grid[index]
		if row.size() != steps:
			row.resize(steps)
		rows.append(row)
	grid = rows
	emit_changed()


## True when the track has a note on [param step].
func is_step_on(track_index: int, step: int) -> bool:
	if track_index < 0 or track_index >= grid.size():
		return false
	var row := grid[track_index]
	return step >= 0 and step < row.size() and row[step] != 0


## Puts a note on a step, or removes it.
func set_step(track_index: int, step: int, on: bool) -> void:
	if track_index < 0 or track_index >= tracks.size() or step < 0 or step >= get_total_steps():
		return
	if grid.size() != tracks.size() or grid[track_index].size() != get_total_steps():
		ensure_grid()
	grid[track_index][step] = 1 if on else 0
	emit_changed()


## Flips one step of one track.
func toggle_track_step(track_index: int, step: int) -> void:
	set_step(track_index, step, not is_step_on(track_index, step))


## Flips a step on every track at once: if the first track has a note there it is cleared
## everywhere, otherwise every track gets one.
func toggle_step(step: int) -> void:
	var turn_on := not is_step_on(0, step)
	for index in tracks.size():
		set_step(index, step, turn_on)


## The indexes of the active tracks that have a note on [param step].
func get_triggered_tracks(step: int) -> PackedInt32Array:
	var result := PackedInt32Array()
	for index in tracks.size():
		if tracks[index] != null and tracks[index].active and is_step_on(index, step):
			result.append(index)
	return result


## Removes every note from the grid.
func clear_grid() -> void:
	for index in grid.size():
		grid[index].fill(0)
	emit_changed()


## The index of the track with [param track_id], or -1.
func find_track(track_id: int) -> int:
	for index in tracks.size():
		if tracks[index] != null and tracks[index].id == track_id:
			return index
	return -1


# --- Raw notes and quantizing ---------------------------------------------

## Adds a recorded note. [param time] is in seconds from the start of the recording.
func add_raw_note(time: float, track_id: int) -> void:
	raw_note_times.append(time)
	raw_note_tracks.append(track_id)


## Removes every recorded note.
func clear_raw_notes() -> void:
	raw_note_times = PackedFloat32Array()
	raw_note_tracks = PackedInt32Array()


## Sorts the recorded notes by time.
func sort_raw_notes() -> void:
	var order: Array[int] = []
	for index in raw_note_times.size():
		order.append(index)
	order.sort_custom(func(a: int, b: int) -> bool: return raw_note_times[a] < raw_note_times[b])
	var times := PackedFloat32Array()
	var ids := PackedInt32Array()
	for index in order:
		times.append(raw_note_times[index])
		ids.append(raw_note_tracks[index])
	raw_note_times = times
	raw_note_tracks = ids


## Snaps the recorded notes to the grid. The length of the pattern becomes the time of the last
## note plus [member end_silence], rounded down to whole beats (at least one), and each note
## goes to the nearest step. The grid is rebuilt, so notes drawn by hand are replaced.
func quantize_raw() -> void:
	if raw_note_times.is_empty():
		return
	sort_raw_notes()
	var last_time := raw_note_times[raw_note_times.size() - 1]
	var beat_duration := get_beat_duration()
	length_beats = maxi(int((last_time + end_silence) / beat_duration), 1)
	var step_duration := get_step_duration()
	var steps := get_total_steps()
	grid = []
	ensure_grid()
	for index in raw_note_times.size():
		var track_index := find_track(raw_note_tracks[index])
		if track_index < 0:
			continue
		var step := clampi(roundi(raw_note_times[index] / step_duration), 0, steps - 1)
		grid[track_index][step] = 1
	emit_changed()


# --- Colors ----------------------------------------------------------------

## A random color from a fixed set of pleasant ones.
static func random_track_color() -> Color:
	return _TRACK_COLORS[randi() % _TRACK_COLORS.size()]


## Gives every track a new random color.
func randomize_track_colors() -> void:
	for track in tracks:
		if track != null:
			track.color = random_track_color()
	emit_changed()
