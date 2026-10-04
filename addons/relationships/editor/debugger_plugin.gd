@tool
extends EditorDebuggerPlugin
## Adds a Relationships tab to the debugger, showing every faction member in
## the running game. The game only sends data while the tab is visible.

const DebuggerTab := preload("debugger_tab.gd")

var _tabs: Dictionary[int, DebuggerTab] = {}


func _has_capture(capture: String) -> bool:
	return capture == "relationships"


func _capture(message: String, data: Array, session_id: int) -> bool:
	if message == "relationships:state" and _tabs.has(session_id):
		_tabs[session_id].show_state(data[0])
		return true
	return false


func _setup_session(session_id: int) -> void:
	var tab := DebuggerTab.new()
	var session := get_session(session_id)
	_tabs[session_id] = tab
	var send_watch := func() -> void:
		if session.is_active():
			session.send_message("relationships:watch", [tab.is_visible_in_tree()])
	tab.visibility_changed.connect(send_watch)
	session.started.connect(send_watch)
	session.stopped.connect(tab.clear)
	session.add_session_tab(tab)
