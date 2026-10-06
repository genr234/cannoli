@tool
extends EditorDebuggerPlugin
## Adds a Juice tab to the debugger, listing the players that are running in the game.
## The game only sends data while the tab is visible.

const DebuggerTab := preload("juice_debugger_tab.gd")

var _tabs: Dictionary[int, DebuggerTab] = {}


func _has_capture(capture: String) -> bool:
	return capture == "juice"


func _capture(message: String, data: Array, session_id: int) -> bool:
	if message == "juice:state" and _tabs.has(session_id):
		_tabs[session_id].show_state(data[0])
		return true
	return false


func _setup_session(session_id: int) -> void:
	var tab := DebuggerTab.new()
	var session := get_session(session_id)
	_tabs[session_id] = tab
	# Bound methods, not a lambda: a lambda holding the session leaks it at exit.
	tab.visibility_changed.connect(_send_watch.bind(session_id))
	session.started.connect(_send_watch.bind(session_id))
	session.stopped.connect(tab.clear)
	session.add_session_tab(tab)


func _send_watch(session_id: int) -> void:
	var session := get_session(session_id)
	if session != null and session.is_active() and _tabs.has(session_id):
		session.send_message("juice:watch", [_tabs[session_id].is_visible_in_tree()])
