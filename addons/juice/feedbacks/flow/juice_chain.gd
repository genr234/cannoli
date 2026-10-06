@tool
@icon("res://addons/juice/icons/flow.svg")
class_name JuiceChain
extends JuiceFeedback
## Plays a list of other players one after the other.
##
## Each step can wait before and after, and can wait for its player to end. The feedback
## lasts as long as the whole chain is expected to take (delays plus the total duration
## of every player), so a pause below waits for it. If the players take longer than
## expected, the steps that are left start at once when that time is over.

@export_group("Chain")
## The steps, played from the first to the last.
@export var items: Array[JuiceChainItem] = []

enum _Phase { BEFORE, PLAYING, AFTER }

var _cursor := 0
var _phase := _Phase.BEFORE
var _wait_left := 0.0
var _running := false


func _has_target() -> bool:
	return false


func _has_randomness() -> bool:
	return false


func _get_color() -> Color:
	return Color("ff9ff3")


func _get_duration() -> float:
	if player == null:
		return 0.0
	var total := 0.0
	for item in items:
		if item == null or item.inactive or _player_of(item) == null:
			continue
		total += item.delay_before + item.delay_after
		total += _player_of(item).get_total_duration() if item.wait_until_complete else 0.0
	return total


func _on_play(_feedback_intensity: float) -> void:
	_cursor = 0
	_phase = _Phase.BEFORE
	_wait_left = 0.0
	_running = true
	_enter_step()
	# Steps without a wait are done in the same frame.
	_advance(0.0)


func _on_tick() -> void:
	_advance(get_delta())


func _on_finished() -> void:
	# Whatever is left plays now, so no step is lost.
	var guard := 0
	while _running and guard < 1000:
		guard += 1
		var item := _current()
		if item != null and _phase == _Phase.BEFORE:
			_play_item(item)
		_cursor += 1
		_phase = _Phase.BEFORE
		if _cursor >= items.size():
			_running = false
	_running = false


func _on_stop() -> void:
	_running = false


func _on_skip_to_end() -> void:
	for item in items:
		if item == null or item.inactive:
			continue
		var target := _player_of(item)
		if target != null:
			target.play()
			target.skip_to_end()
	_running = false


func _on_restore() -> void:
	for i in range(items.size() - 1, -1, -1):
		var item := items[i]
		var target := _player_of(item) if item != null else null
		if target != null:
			target.restore_initial_values()


func _player_of(item: JuiceChainItem) -> JuicePlayer:
	var found := resolve(item.player) as JuicePlayer
	return found if found != player else null


func _current() -> JuiceChainItem:
	while _cursor < items.size():
		var item := items[_cursor]
		if item != null and not item.inactive and _player_of(item) != null:
			return item
		_cursor += 1
	return null


# Starts the delay in front of the current step.
func _enter_step() -> void:
	var item := _current()
	_phase = _Phase.BEFORE
	_wait_left = item.delay_before if item != null else 0.0


func _play_item(item: JuiceChainItem) -> void:
	_player_of(item).play(get_play_position(), get_intensity())


func _advance(dt: float) -> void:
	var left := dt
	var guard := 0
	while _running and guard < 256:
		guard += 1
		var item := _current()
		if item == null:
			_running = false
			return
		match _phase:
			_Phase.BEFORE:
				if _wait_left > left:
					_wait_left -= left
					return
				left -= _wait_left
				_play_item(item)
				_phase = _Phase.PLAYING
			_Phase.PLAYING:
				if item.wait_until_complete and _player_of(item).is_playing():
					return
				_phase = _Phase.AFTER
				_wait_left = item.delay_after
			_Phase.AFTER:
				if _wait_left > left:
					_wait_left -= left
					return
				left -= _wait_left
				_cursor += 1
				_enter_step()
