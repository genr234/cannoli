class_name JuiceTimeScaleStack
extends Object
## Lets several time scale changes overlap without fighting over [member Engine.time_scale].
##
## Every owner (a feedback, or your own code) sets one entry under its own key. The
## strongest entry wins: the lowest value when any entry slows time down, the highest
## when all of them speed it up. When the last entry is removed, the time scale
## from before the first entry comes back. Nothing happens in the editor.

static var _entries: Dictionary[int, float] = {}
static var _base_scale := 1.0


## Sets or updates the time scale requested by [param key]. Use any unique int, such as
## [method Object.get_instance_id].
static func set_entry(key: int, scale: float) -> void:
	if Engine.is_editor_hint():
		return
	if _entries.is_empty():
		_base_scale = Engine.time_scale
	_entries[key] = maxf(scale, 0.0)
	_apply()


## Removes the entry of [param key]. Returns true when there was one.
static func remove_entry(key: int) -> bool:
	if not _entries.has(key):
		return false
	_entries.erase(key)
	_apply()
	return true


## Removes every entry and brings back the time scale from before the first one.
static func clear() -> void:
	if _entries.is_empty():
		return
	_entries.clear()
	_apply()


## True when the key has an entry right now.
static func has_entry(key: int) -> bool:
	return _entries.has(key)


## True when any entry is active.
static func is_active() -> bool:
	return not _entries.is_empty()


## The value Engine.time_scale takes with the current entries.
static func get_effective_scale() -> float:
	if _entries.is_empty():
		return _base_scale
	var slowest := INF
	var fastest := 0.0
	for value in _entries.values():
		slowest = minf(slowest, value)
		fastest = maxf(fastest, value)
	return _base_scale * (slowest if slowest < 1.0 else fastest)


static func _apply() -> void:
	Engine.time_scale = get_effective_scale()
