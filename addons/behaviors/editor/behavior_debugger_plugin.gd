@tool
extends EditorDebuggerPlugin
## Adds a Behaviors tab to the debugger. It lists the agents of the running game, draws
## the live task states of the selected one on the Behaviors screen and lets you inspect
## its variables, step through recent history and control it.

const DebuggerTab := preload("behavior_debugger_tab.gd")

## Returns the Behaviors main screen control. Set by the plugin.
var get_behavior_editor: Callable

var _tabs: Dictionary[int, DebuggerTab] = {}


func _has_capture(capture: String) -> bool:
	return capture == "behaviors"


func _capture(message: String, data: Array, session_id: int) -> bool:
	var tab: DebuggerTab = _tabs.get(session_id)
	if tab == null:
		return false
	match message:
		"behaviors:agents":
			tab.show_agents(data[0])
		"behaviors:state":
			tab.receive_state(data)
		_:
			return false
	return true


func _setup_session(session_id: int) -> void:
	var tab := DebuggerTab.new()
	var session := get_session(session_id)
	_tabs[session_id] = tab
	tab.get_behavior_editor = _get_editor
	tab.message_requested.connect(_send.bind(session_id))
	tab.watching.connect(_on_tab_watching.bind(tab))
	tab.visibility_changed.connect(_on_tab_shown.bind(session_id))
	session.started.connect(_on_session_started.bind(session_id))
	session.stopped.connect(tab.session_stopped)
	session.breaked.connect(_on_session_breaked.bind(session_id))
	session.continued.connect(_on_session_continued.bind(session_id))
	session.add_session_tab(tab)


## Redraws the overlay, for example after the Behaviors screen opened another tree.
func refresh_overlay() -> void:
	for tab in _tabs.values():
		tab.refresh_overlay()


## Removes everything drawn on the Behaviors screen and stops watching.
func release_all() -> void:
	for tab in _tabs.values():
		if is_instance_valid(tab):
			tab.release()


func _get_editor() -> Control:
	return get_behavior_editor.call() if get_behavior_editor.is_valid() else null


func _send(message: String, args: Array, session_id: int) -> void:
	var session := get_session(session_id)
	if session != null and session.is_active():
		session.send_message(message, args)


# Only one agent drives the overlay at a time, so a tab that starts watching releases the others.
func _on_tab_watching(tab: DebuggerTab) -> void:
	for other in _tabs.values():
		if other != tab:
			other.release()


func _on_tab_shown(session_id: int) -> void:
	var tab: DebuggerTab = _tabs.get(session_id)
	if tab != null and tab.is_visible_in_tree():
		_send("behaviors:request_agents", [], session_id)


func _on_session_started(session_id: int) -> void:
	_send("behaviors:request_agents", [], session_id)


func _on_session_breaked(_can_debug: bool, session_id: int) -> void:
	if _tabs.has(session_id):
		_tabs[session_id].set_stale(true)


func _on_session_continued(session_id: int) -> void:
	if _tabs.has(session_id):
		_tabs[session_id].set_stale(false)
		_send("behaviors:request_agents", [], session_id)
