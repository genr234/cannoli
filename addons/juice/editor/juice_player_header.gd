@tool
extends HBoxContainer
## Transport bar at the top of a [JuicePlayer] inspector: play, play reversed, stop,
## pause, skip to end and restore, plus the total duration of the list.

const Util := preload("juice_editor_util.gd")
const Preview := preload("juice_preview.gd")

var _player: JuicePlayer
var _pause_button := Button.new()
var _status := Label.new()
var _total_timer := 0.0
var _total_text := ""


func _init(player: JuicePlayer) -> void:
	_player = player
	_add_button("Play", Util.icon(&"Play"), "Play", "Preview the whole list in the editor.", _on_play)
	_add_button("Play reversed", Util.icon(&"PlayBackwards"), "<", "Preview the list backwards.", _on_play_reversed)
	_add_button("Stop", Util.icon(&"Stop"), "Stop", "Stop and restore the values.", _on_stop)
	_pause_button.tooltip_text = "Pause or resume the preview."
	_pause_button.pressed.connect(_on_pause)
	Util.set_icon(_pause_button, Util.icon(&"Pause"), "Pause")
	add_child(_pause_button)
	_add_button("Skip to end", Util.addon_icon("skip_end"), ">>", "Jump to the end of the play.", _on_skip)
	_add_button("Restore", Util.addon_icon("restore"), "Restore", "Put every target back as it was before the preview.", _on_restore)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_status)
	_refresh_total()
	_update_status()


func _process(delta: float) -> void:
	_total_timer += delta
	if _total_timer >= 0.25:
		_total_timer = 0.0
		_refresh_total()
	_update_status()


func _add_button(tip_name: String, icon_texture: Texture2D, fallback: String, tip: String, callback: Callable) -> void:
	var button := Button.new()
	button.tooltip_text = "%s. %s" % [tip_name, tip]
	Util.set_icon(button, icon_texture, fallback)
	button.pressed.connect(callback)
	add_child(button)


func _refresh_total() -> void:
	if not is_instance_valid(_player):
		return
	_total_text = "Total %s" % Util.format_time(_player.get_total_duration())
	if _player.has_endless_feedback():
		_total_text += "  ∞"


func _update_status() -> void:
	if not is_instance_valid(_player):
		return
	if _player.is_playing():
		_status.text = "%s / %s" % [Util.format_time(_player.get_elapsed_time()), _total_text.trim_prefix("Total ")]
	else:
		_status.text = _total_text
	var paused := _player.is_paused()
	var wanted := &"Play" if paused else &"Pause"
	_pause_button.tooltip_text = "Resume the preview." if paused else "Pause the preview."
	if _pause_button.icon != null:
		_pause_button.icon = Util.icon(wanted)
	else:
		_pause_button.text = "Resume" if paused else "Pause"
	_pause_button.disabled = not _player.is_playing()


func _can_preview() -> bool:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return false
	if _player.feedbacks.is_empty():
		return false
	return true


func _on_play() -> void:
	if _can_preview():
		_player.preview_play()


func _on_play_reversed() -> void:
	if _can_preview():
		Preview.play_reversed(_player)


func _on_stop() -> void:
	if is_instance_valid(_player):
		_player.preview_stop()


func _on_pause() -> void:
	if not is_instance_valid(_player):
		return
	if _player.is_paused():
		_player.resume()
	else:
		_player.pause()


func _on_skip() -> void:
	if is_instance_valid(_player) and _player.is_playing():
		_player.skip_to_end()


func _on_restore() -> void:
	if is_instance_valid(_player):
		_player.restore_initial_values()
