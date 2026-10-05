class_name QuestsTime
extends RefCounted
## The clock used for quest cooldowns, time limits and timers.
##
## In [constant STANDARD] mode, time advances with the [QuestManager]'s process
## frames, so it follows [member Engine.time_scale] and stops while the scene
## tree is paused. [constant REALTIME] never pauses. In [constant MANUAL] mode
## you set [member manual_time] and [member manual_delta] yourself.

enum Mode { STANDARD, REALTIME, MANUAL }

static var mode := Mode.STANDARD
static var manual_time := 0.0
static var manual_delta := 0.0
static var manual_paused := false

static var _standard_time := 0.0
static var _standard_delta := 0.0
static var _standard_paused := false


## Current game time in seconds.
static func now() -> float:
	match mode:
		Mode.REALTIME:
			return Time.get_ticks_msec() / 1000.0
		Mode.MANUAL:
			return manual_time
	return _standard_time


## Seconds since the last frame.
static func delta() -> float:
	match mode:
		Mode.MANUAL:
			return manual_delta
	return _standard_delta


static func is_paused() -> bool:
	match mode:
		Mode.REALTIME:
			return false
		Mode.MANUAL:
			return manual_paused
	return _standard_paused or is_zero_approx(Engine.time_scale)


## Called by [QuestManager] every frame. You don't need to call it.
static func advance(frame_delta: float, paused := false) -> void:
	_standard_delta = 0.0 if paused else frame_delta
	_standard_time += _standard_delta
	_standard_paused = paused


## Resets standard time to zero and manual time to manual defaults.
static func reset() -> void:
	_standard_time = 0.0
	_standard_delta = 0.0
	_standard_paused = false
	manual_time = 0.0
	manual_delta = 0.0
	manual_paused = false
