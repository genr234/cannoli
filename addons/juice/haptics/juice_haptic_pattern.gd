@tool
@icon("res://addons/juice/icons/haptics.svg")
class_name JuiceHapticPattern
extends Resource
## A vibration pattern: a list of [JuiceHapticStep]s played one after the other.
##
## Build your own in the inspector, or take a ready made one with [method preset]. The
## presets are small gestures such as a tick for a selection, a rising buzz for success, or a
## double buzz for failure. [JuiceHaptics] plays patterns on gamepads and phones.

## Ready made patterns for [method preset].
enum Preset {
	SELECTION,
	SUCCESS,
	WARNING,
	FAILURE,
	LIGHT_IMPACT,
	MEDIUM_IMPACT,
	HEAVY_IMPACT,
	RIGID_IMPACT,
	SOFT_IMPACT,
}

static var _preset_cache: Dictionary[int, JuiceHapticPattern] = {}

## The steps, played in order.
@export var steps: Array[JuiceHapticStep] = []


## Returns the total length of the pattern in seconds.
func get_duration() -> float:
	var total := 0.0
	for step in steps:
		if step != null:
			total += maxf(step.duration, 0.0)
	return total


## Returns the index of the step playing at [param time] seconds, or -1 for an empty pattern.
## Times past the end give the last step.
func get_step_index(time: float) -> int:
	var elapsed := 0.0
	var last := -1
	for i in steps.size():
		var step := steps[i]
		if step == null or step.duration <= 0.0:
			continue
		last = i
		elapsed += step.duration
		if time < elapsed:
			return i
	return last


## Returns the start time of step [param index] in seconds.
func get_step_start(index: int) -> float:
	var elapsed := 0.0
	for i in mini(index, steps.size()):
		if steps[i] != null:
			elapsed += maxf(steps[i].duration, 0.0)
	return elapsed


## Returns a ready made pattern. The same instance is returned each time, so do not edit it.
static func preset(kind: Preset) -> JuiceHapticPattern:
	if not _preset_cache.has(kind):
		_preset_cache[kind] = _build(kind)
	return _preset_cache[kind]


## Makes a pattern from arrays of durations and strengths, one entry per step.
static func make(durations: PackedFloat32Array, weak: PackedFloat32Array, strong: PackedFloat32Array) -> JuiceHapticPattern:
	var pattern := JuiceHapticPattern.new()
	for i in durations.size():
		var w := weak[i] if i < weak.size() else 0.0
		var s := strong[i] if i < strong.size() else 0.0
		pattern.steps.append(JuiceHapticStep.make(durations[i], w, s))
	return pattern


static func _build(kind: Preset) -> JuiceHapticPattern:
	match kind:
		Preset.SELECTION:
			return make([0.04], [0.47], [0.0])
		Preset.LIGHT_IMPACT:
			return make([0.04], [0.16], [0.0])
		Preset.MEDIUM_IMPACT:
			return make([0.08], [0.47], [0.2])
		Preset.HEAVY_IMPACT:
			return make([0.16], [1.0], [1.0])
		Preset.RIGID_IMPACT:
			return make([0.04], [1.0], [0.6])
		Preset.SOFT_IMPACT:
			return make([0.16], [0.0], [0.16])
		Preset.SUCCESS:
			return make([0.04, 0.04, 0.16], [0.16, 0.0, 1.0], [0.0, 0.0, 1.0])
		Preset.WARNING:
			return make([0.12, 0.12, 0.04], [1.0, 0.0, 0.47], [1.0, 0.0, 0.0])
		Preset.FAILURE:
			return make(
				[0.08, 0.04, 0.08, 0.04, 0.16, 0.04, 0.04],
				[0.47, 0.0, 0.47, 0.0, 1.0, 0.0, 0.16],
				[0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0])
	return JuiceHapticPattern.new()
