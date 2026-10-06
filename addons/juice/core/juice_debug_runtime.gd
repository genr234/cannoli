class_name JuiceDebugRuntime
extends RefCounted
## Game side of the "Juice" debugger tab. Reports the players that are running.
##
## A [JuicePlayer] opts in with one call, [code]JuiceDebugRuntime.track(self)[/code] in its
## [code]_enter_tree[/code]. It does nothing outside a debug session started from the editor, and
## sends data only while the Juice tab is visible. Protocol: the editor sends [code]juice:watch[/code]
## with a bool, the game answers [code]juice:state[/code] with an array of dictionaries
## ([code]name, path, elapsed, total, endless, paused, plays, active[/code]).

const CAPTURE := "juice"
const SEND_INTERVAL := 0.1

static var _players: Array[WeakRef] = []
static var _watching := false
static var _pump: Node = null


## Starts reporting [param player] to the debugger. Safe to call many times.
static func track(player: JuicePlayer) -> void:
	if not EngineDebugger.is_active() or Engine.is_editor_hint():
		return
	for reference in _players:
		if reference.get_ref() == player:
			return
	_players.append(weakref(player))
	if _pump == null or not is_instance_valid(_pump):
		_pump = _Pump.new()
		_pump.name = &"JuiceDebugPump"
		# The player is not ready to take children while it enters the tree.
		player.get_tree().root.add_child.call_deferred(_pump)


## Builds the list sent to the editor. Only players that are running are listed.
static func snapshot() -> Array[Dictionary]:
	var state: Array[Dictionary] = []
	var alive: Array[WeakRef] = []
	for reference in _players:
		var player := reference.get_ref() as JuicePlayer
		if player == null:
			continue
		alive.append(reference)
		if not player.is_playing():
			continue
		var active: Array[String] = []
		for feedback in player.get_feedbacks():
			if feedback.is_busy():
				active.append(feedback.get_display_label())
		state.append({
			"name": String(player.name),
			"path": String(player.get_path()) if player.is_inside_tree() else "",
			"elapsed": player.get_elapsed_time(),
			"total": player.get_total_duration(),
			"endless": player.has_endless_feedback(),
			"paused": player.is_paused(),
			"plays": player.get_play_count(),
			"active": active,
		})
	_players = alive
	return state


class _Pump extends Node:
	var _timer := 0.0
	var _sent_empty := false

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	# The capture lives on this node, not on a static function, so it is
	# unregistered while the engine can still do it cleanly.
	func _enter_tree() -> void:
		if not EngineDebugger.has_capture(JuiceDebugRuntime.CAPTURE):
			EngineDebugger.register_message_capture(JuiceDebugRuntime.CAPTURE, _on_message)

	func _exit_tree() -> void:
		if EngineDebugger.has_capture(JuiceDebugRuntime.CAPTURE):
			EngineDebugger.unregister_message_capture(JuiceDebugRuntime.CAPTURE)

	func _on_message(message: String, data: Array) -> bool:
		if message == "watch":
			JuiceDebugRuntime._watching = bool(data[0]) if not data.is_empty() else false
			return true
		return false

	func _process(delta: float) -> void:
		if not JuiceDebugRuntime._watching or not EngineDebugger.is_active():
			return
		_timer += delta
		if _timer < JuiceDebugRuntime.SEND_INTERVAL:
			return
		_timer = 0.0
		var state := JuiceDebugRuntime.snapshot()
		# Do not repeat an empty list, the tab already shows it.
		if state.is_empty():
			if _sent_empty:
				return
			_sent_empty = true
		else:
			_sent_empty = false
		EngineDebugger.send_message("juice:state", [state])
