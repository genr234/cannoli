@tool
extends EditorDebuggerPlugin
## Adds a Quests tab to the debugger that shows every quest list in the running
## game and lets you change quest states, node states and counters. The game only
## sends data while the tab or the Quest Editor is looking at it.

const DebuggerTab := preload("debugger_tab.gd")

## Emitted with each state snapshot from the game.
signal state_received(data: Dictionary)
## Emitted when the game session ends.
signal session_stopped

var _tabs: Dictionary[int, DebuggerTab] = {}
var _editor_watching := false
var _last_state: Dictionary = {}


## The most recent snapshot, or an empty dictionary when no game is running.
func get_last_state() -> Dictionary:
	return _last_state


func _has_capture(capture: String) -> bool:
	return capture == "quests"


func _capture(message: String, data: Array, session_id: int) -> bool:
	if message == "quests:state" and _tabs.has(session_id):
		_last_state = data[0]
		_tabs[session_id].show_state(_last_state)
		state_received.emit(_last_state)
		return true
	return false


func _setup_session(session_id: int) -> void:
	var tab := DebuggerTab.new()
	var session := get_session(session_id)
	_tabs[session_id] = tab
	tab.visibility_changed.connect(_send_watch.bind(session_id))
	session.started.connect(_send_watch.bind(session_id))
	session.stopped.connect(_on_session_stopped.bind(session_id))
	tab.command.connect(send_command)
	session.add_session_tab(tab)


func _send_watch(session_id: int) -> void:
	var session := get_session(session_id)
	if session != null and session.is_active() and _tabs.has(session_id):
		session.send_message("quests:watch", [_tabs[session_id].is_visible_in_tree() or _editor_watching])


func _on_session_stopped(session_id: int) -> void:
	if _tabs.has(session_id):
		_tabs[session_id].clear()
	_last_state = {}
	session_stopped.emit()


## Tells the game to keep sending snapshots because the Quest Editor wants them.
func set_editor_watching(watching: bool) -> void:
	if _editor_watching == watching:
		return
	_editor_watching = watching
	for session_id in _tabs:
		_send_watch(session_id)


## Sends a `quests:*` command to every running game.
func send_command(message: String, args: Array) -> void:
	for session_id in _tabs:
		var session := get_session(session_id)
		if session != null and session.is_active():
			session.send_message(message, args)


func is_game_running() -> bool:
	for session_id in _tabs:
		var session := get_session(session_id)
		if session != null and session.is_active():
			return true
	return false
