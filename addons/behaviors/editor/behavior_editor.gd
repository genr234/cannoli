@tool
extends VBoxContainer
## The Behaviors main screen: a graph canvas for the open tree, a palette of tasks, a
## variables panel and a list of problems.
##
## Every change goes through [method commit], which records a snapshot pair in the
## undo history. The debugger drives the live overlay with [method set_runtime_state].

const NodeView := preload("behavior_graph_node.gd")
const ActionMenu := preload("behavior_action_menu.gd")
const Palette := preload("behavior_palette.gd")
const QuickSearch := preload("behavior_quick_search.gd")
const VariablesPanel := preload("behavior_variables_panel.gd")

const SETTING_AUTO_SAVE := "behaviors/editor/auto_save"
const ENTRY_NAME := &"Entry"

## The open tree changed.
signal tree_opened(tree: BehaviorTree)

var undo_redo: EditorUndoRedoManager

var _tree: BehaviorTree
var _agent: BehaviorAgent
var _history: Array[BehaviorTree] = []
var _history_index := -1
var _nodes: Dictionary = {}
var _task_by_name: Dictionary = {}
var _frame_nodes: Dictionary = {}
var _entry: NodeView
var _runtime_states: Dictionary = {}
var _clipboard: Array[BehaviorTask] = []
var _link_mode: Dictionary = {}
var _pending_link: Dictionary = {}
var _pending_select: Array[StringName] = []
var _inspect_pending := false
var _context_position := Vector2.ZERO
var _issues: Array[Dictionary] = []
var _refresh_queued := false
var _selection_queued := false
var _rebuilding := false
var _file_mode := ""
var _prompt_callback: Callable

var _toolbar := HBoxContainer.new()
var _back_button := Button.new()
var _forward_button := Button.new()
var _title_label := Label.new()
var _new_button := Button.new()
var _open_button := Button.new()
var _save_button := Button.new()
var _arrange_button := Button.new()
var _frame_button := Button.new()
var _link_label := Label.new()
var _issues_button := Button.new()
var _variables_button := Button.new()
var _auto_save := CheckBox.new()
var _outer_split := HSplitContainer.new()
var _palette := Palette.new()
var _inner_split := HSplitContainer.new()
var _graph_holder := VBoxContainer.new()
var _graph_split := VSplitContainer.new()
var _stage := VBoxContainer.new()
var _graph := GraphEdit.new()
var _empty_box := VBoxContainer.new()
var _empty_label := Label.new()
var _create_button := Button.new()
var _issue_list := ItemList.new()
var _variables := VariablesPanel.new()
var _menu := ActionMenu.new()
var _quick := QuickSearch.new()
var _file_dialog := EditorFileDialog.new()
var _prompt := ConfirmationDialog.new()
var _prompt_edit := LineEdit.new()
var _save_timer := Timer.new()


func _init() -> void:
	name = "Behaviors"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_build_ui()
	_palette.rebuild()
	_update_toolbar()
	var inspector := EditorInterface.get_inspector()
	inspector.property_edited.connect(_on_property_edited)
	if undo_redo != null:
		undo_redo.version_changed.connect(_on_version_changed)
	EditorInterface.get_resource_filesystem().script_classes_updated.connect(_on_script_classes_updated)
	visibility_changed.connect(_on_visibility_changed)


func _exit_tree() -> void:
	if not _save_timer.is_stopped():
		_save_now()


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and key.keycode == KEY_ESCAPE and not _link_mode.is_empty():
		_end_link_mode()
		get_viewport().set_input_as_handled()


#region Public API

## Opens a tree, or the tree of an agent. An agent without a tree offers to create one.
func edit_object(object: Object) -> void:
	if object is BehaviorTree:
		_agent = null
		open_tree(object)
	elif object is BehaviorAgent:
		_agent = object
		if _agent.tree:
			open_tree(_agent.tree)
		else:
			_set_tree(null)
			_empty_label.text = "%s has no tree." % _agent.name
			_update_toolbar()


## Opens [param tree] in the canvas and adds it to the history.
func open_tree(tree: BehaviorTree, push_history := true) -> void:
	if tree == null:
		return
	if push_history and tree != _tree:
		_history.resize(_history_index + 1)
		_history.append(tree)
		_history_index = _history.size() - 1
	_set_tree(tree)
	tree_opened.emit(tree)


## The tree shown in the canvas, or null.
func get_edited_tree() -> BehaviorTree:
	return _tree


## The tree that owns [param task], or null when the open tree does not hold it.
func get_tree_for_task(task: BehaviorTask) -> BehaviorTree:
	if _tree and _tree.get_tasks(true).has(task):
		return _tree
	return null


## Draws live state on the tasks. [param states] maps a task id (int) to a dictionary
## with [code]status[/code] ([enum BehaviorTask.Status]), [code]running[/code] (bool)
## and [code]reevaluating[/code] (bool). Running tasks get a green border, finished
## ones a check or a cross, and reevaluating ones a small arrow badge. Tasks missing
## from the dictionary are drawn normally.
func set_runtime_state(states: Dictionary) -> void:
	_runtime_states = states
	_apply_runtime()


## Removes everything drawn by [method set_runtime_state].
func clear_runtime_state() -> void:
	_runtime_states = {}
	_apply_runtime()


## Makes a change to the open tree undoable. [param mutate] changes the tree. The
## change is skipped when nothing differs. Returns true when something changed.
func commit(action_name: String, mutate: Callable, rebuild := true) -> bool:
	if _tree == null:
		return false
	var before := BehaviorGraphOps.snapshot(_tree)
	mutate.call()
	_tree.ensure_ids()
	var after := BehaviorGraphOps.snapshot(_tree)
	if before == after:
		return false
	if undo_redo != null:
		undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, _tree)
		undo_redo.add_do_method(self, "_restore", _tree, after)
		undo_redo.add_undo_method(self, "_restore", _tree, before)
		undo_redo.commit_action(false)
	_after_change(rebuild)
	return true


## Tells the editor that a task changed outside the graph, such as a binding.
func notify_task_changed(_task: BehaviorTask = null) -> void:
	_queue_refresh()
	_mark_modified()


## Asks the user to click a task in the graph and links it to [param property] of
## [param task]. Only tasks of [param required_class] are accepted.
func begin_link_mode(task: BehaviorTask, property: StringName, required_class: String) -> void:
	if get_tree_for_task(task) == null:
		return
	_link_mode = {"task": task, "property": property, "class": required_class}
	_link_label.text = "Click a %s task to link it. Esc cancels." % required_class.trim_prefix("Behavior").capitalize()
	_link_label.visible = true
	_graph.grab_focus()


## The number of problems found in the open tree.
func get_issue_count() -> int:
	return _issues.size()

#endregion

#region UI

func _build_ui() -> void:
	_build_toolbar()
	_outer_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_outer_split)
	_outer_split.add_child(_palette)
	_palette.task_activated.connect(_on_palette_activated)
	_inner_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_outer_split.add_child(_inner_split)
	_graph_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inner_split.add_child(_graph_holder)
	_graph_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_holder.add_child(_graph_split)
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_split.add_child(_stage)
	_setup_graph()
	_stage.add_child(_graph)
	_graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_empty_box()
	_stage.add_child(_empty_box)
	_issue_list.custom_minimum_size.y = 110.0
	_issue_list.visible = false
	_issue_list.item_selected.connect(_on_issue_selected)
	_graph_split.add_child(_issue_list)
	_variables.commit = commit
	_variables.undo_redo = undo_redo
	_variables.inspect_requested.connect(_inspect)
	_inner_split.add_child(_variables)
	for node: Node in [_menu, _quick, _file_dialog, _prompt, _save_timer]:
		add_child(node)
	_quick.chosen.connect(_on_quick_chosen)
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.add_filter("*.tres", "Behavior tree")
	_file_dialog.file_selected.connect(_on_file_selected)
	_prompt.add_child(_prompt_edit)
	_prompt.register_text_enter(_prompt_edit)
	_prompt.confirmed.connect(func() -> void:
		if _prompt_callback.is_valid():
			_prompt_callback.call(_prompt_edit.text))
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.6
	_save_timer.timeout.connect(_save_now)


func _build_toolbar() -> void:
	_toolbar.add_theme_constant_override("separation", 6)
	add_child(_toolbar)
	var theme := EditorInterface.get_editor_theme()
	_back_button.icon = theme.get_icon("Back", "EditorIcons")
	_back_button.tooltip_text = "Previous tree"
	_back_button.pressed.connect(func() -> void: _history_go(-1))
	_toolbar.add_child(_back_button)
	_forward_button.icon = theme.get_icon("Forward", "EditorIcons")
	_forward_button.tooltip_text = "Next tree"
	_forward_button.pressed.connect(func() -> void: _history_go(1))
	_toolbar.add_child(_forward_button)
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.text = "No tree open"
	_toolbar.add_child(_title_label)
	_toolbar.add_child(VSeparator.new())
	_new_button.text = "New Tree"
	_new_button.pressed.connect(func() -> void: _ask_file("new"))
	_toolbar.add_child(_new_button)
	_open_button.text = "Open"
	_open_button.pressed.connect(func() -> void: _ask_file("open"))
	_toolbar.add_child(_open_button)
	_save_button.text = "Save"
	_save_button.pressed.connect(func() -> void: _save_now(true))
	_toolbar.add_child(_save_button)
	_toolbar.add_child(VSeparator.new())
	_arrange_button.text = "Arrange"
	_arrange_button.tooltip_text = "Lay the tree out from left to right."
	_arrange_button.pressed.connect(_arrange)
	_toolbar.add_child(_arrange_button)
	_frame_button.text = "Add Frame"
	_frame_button.tooltip_text = "Add a comment frame. With tasks selected, it surrounds them."
	_frame_button.pressed.connect(_add_frame)
	_toolbar.add_child(_frame_button)
	_link_label.visible = false
	_link_label.add_theme_color_override("font_color", Color("f2c14e"))
	_toolbar.add_child(_link_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar.add_child(spacer)
	_issues_button.text = "⚠ 0"
	_issues_button.toggle_mode = true
	_issues_button.tooltip_text = "Problems found in the tree."
	_issues_button.toggled.connect(func(pressed: bool) -> void: _issue_list.visible = pressed)
	_toolbar.add_child(_issues_button)
	_variables_button.text = "Variables"
	_variables_button.toggle_mode = true
	_variables_button.button_pressed = true
	_variables_button.toggled.connect(func(pressed: bool) -> void: _variables.visible = pressed)
	_toolbar.add_child(_variables_button)
	_auto_save.text = "Auto-save"
	_auto_save.tooltip_text = "Save the tree file after every change."
	_auto_save.button_pressed = ProjectSettings.get_setting(SETTING_AUTO_SAVE, true)
	_auto_save.toggled.connect(func(pressed: bool) -> void: ProjectSettings.set_setting(SETTING_AUTO_SAVE, pressed))
	_toolbar.add_child(_auto_save)


func _build_empty_box() -> void:
	_empty_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_empty_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty_label.text = "Select a tree or an agent, or create a new tree."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_box.add_child(_empty_label)
	_create_button.text = "Create Tree"
	_create_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_create_button.pressed.connect(_create_tree_for_agent)
	_empty_box.add_child(_create_button)


func _setup_graph() -> void:
	_graph.right_disconnects = true
	_graph.show_arrange_button = false
	_graph.minimap_enabled = true
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.connection_to_empty.connect(_on_connection_to_empty)
	_graph.connection_from_empty.connect(_on_connection_from_empty)
	_graph.delete_nodes_request.connect(_on_delete_nodes_request)
	_graph.node_selected.connect(_on_node_selected)
	_graph.node_deselected.connect(func(_node: Node) -> void: _queue_selection())
	_graph.end_node_move.connect(func() -> void: _sync_layout("Move"))
	_graph.popup_request.connect(_on_popup_request)
	_graph.copy_nodes_request.connect(_copy_selected)
	_graph.cut_nodes_request.connect(func() -> void:
		_copy_selected()
		_delete_selected())
	_graph.paste_nodes_request.connect(_paste)
	_graph.duplicate_nodes_request.connect(_duplicate_selected)
	_graph.gui_input.connect(_on_graph_input)
	_graph.set_drag_forwarding(Callable(), _can_drop_on_graph, _drop_on_graph)

#endregion

#region Opening

func _set_tree(tree: BehaviorTree) -> void:
	_tree = tree
	if tree:
		tree.ensure_ids()
	for child in _graph.get_children():
		if child is GraphElement:
			child.selected = false
	_pending_select = []
	_end_link_mode()
	_runtime_states = {}
	_graph.visible = tree != null
	_empty_box.visible = tree == null
	_create_button.visible = tree == null and _agent != null and is_instance_valid(_agent)
	if tree == null and _agent == null:
		_empty_label.text = "Select a tree or an agent, or create a new tree."
	_variables.set_tree(tree)
	_rebuild_graph()
	if tree:
		_scroll_to_start.call_deferred()
	_update_toolbar()


func _history_go(step: int) -> void:
	var target := _history_index + step
	if target < 0 or target >= _history.size():
		return
	_history_index = target
	_agent = null
	_set_tree(_history[target])
	tree_opened.emit(_tree)
	_inspect(_tree)


func _update_toolbar() -> void:
	_back_button.disabled = _history_index <= 0
	_forward_button.disabled = _history_index >= _history.size() - 1
	for button: Button in [_save_button, _arrange_button, _frame_button]:
		button.disabled = _tree == null
	if _tree == null:
		_title_label.text = "No tree open"
		return
	var path := _tree.resource_path
	if path.is_empty() or "::" in path:
		_title_label.text = "%s (built-in)" % (_agent.name if _agent and is_instance_valid(_agent) else "Tree")
		_title_label.tooltip_text = path
	else:
		_title_label.text = path.get_file()
		_title_label.tooltip_text = path


func _scroll_to_start() -> void:
	if _tree == null or _entry == null:
		return
	_graph.zoom = 1.0
	_graph.scroll_offset = _entry.position_offset - Vector2(60, _graph.size.y * 0.4)


func _create_tree_for_agent() -> void:
	if _agent == null or not is_instance_valid(_agent):
		return
	var tree := BehaviorGraphOps.new_tree()
	if undo_redo != null:
		undo_redo.create_action("Create Behavior Tree", UndoRedo.MERGE_DISABLE, _agent)
		undo_redo.add_do_property(_agent, "tree", tree)
		undo_redo.add_undo_property(_agent, "tree", null)
		undo_redo.commit_action()
	else:
		_agent.tree = tree
	EditorInterface.mark_scene_as_unsaved()
	open_tree(tree)

#endregion

#region Graph building

func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	_rebuild_graph()
	_variables.refresh()


func _rebuild_graph() -> void:
	_rebuilding = true
	var selected: Array[StringName] = _pending_select.duplicate()
	if selected.is_empty():
		for child in _graph.get_children():
			if child is GraphElement and child.selected:
				selected.append(child.name)
	_pending_select = []
	_graph.clear_connections()
	for child in _graph.get_children():
		if child is GraphElement:
			_graph.remove_child(child)
			child.queue_free()
	_nodes.clear()
	_task_by_name.clear()
	_frame_nodes.clear()
	_entry = null
	if _tree != null:
		_build_frames()
		_build_entry()
		_build_tasks()
		_build_connections()
		for node_name in selected:
			var element := _graph.get_node_or_null(NodePath(node_name)) as GraphElement
			if element:
				element.selected = true
	_rebuilding = false
	_apply_links()
	_apply_runtime()
	_refresh_issues()
	_update_toolbar()
	if _inspect_pending:
		_inspect_pending = false
		_update_selection()


func _build_frames() -> void:
	for frame_data: Dictionary in BehaviorGraphOps.get_frames(_tree):
		var id := int(frame_data.get("id", 0))
		var frame := GraphFrame.new()
		frame.name = "f%d" % id
		frame.title = frame_data.get("title", "Comment")
		frame.tint_color_enabled = true
		frame.tint_color = frame_data.get("color", Color(0.3, 0.4, 0.6, 0.35))
		var rect: Rect2 = frame_data.get("rect", Rect2(0, 0, 320, 200))
		frame.position_offset = rect.position
		frame.size = rect.size
		frame.resizable = true
		frame.autoshrink_enabled = false
		frame.resize_request.connect(func(new_size: Vector2) -> void: frame.size = new_size)
		frame.resize_end.connect(func(_new_size: Vector2) -> void: _sync_layout("Resize Frame"))
		frame.gui_input.connect(_on_frame_input.bind(frame))
		var picker := ColorPickerButton.new()
		picker.custom_minimum_size = Vector2(26, 0)
		picker.color = frame.tint_color
		picker.edit_alpha = true
		picker.color_changed.connect(func(color: Color) -> void: frame.tint_color = color)
		picker.popup_closed.connect(func() -> void: _sync_layout("Frame Color"))
		frame.get_titlebar_hbox().add_child(picker)
		_graph.add_child(frame)
		_frame_nodes[id] = frame


func _build_entry() -> void:
	_entry = NodeView.new()
	_entry.name = ENTRY_NAME
	_entry.setup_entry()
	var default_position := Vector2(-BehaviorGraphOps.ENTRY_SIZE.x - BehaviorGraphOps.COLUMN_GAP, 0.0)
	_entry.position_offset = _tree.editor_data.get(BehaviorGraphOps.KEY_ENTRY, default_position)
	_entry.context_requested.connect(_on_node_context)
	_graph.add_child(_entry)


func _build_tasks() -> void:
	var hidden := BehaviorGraphOps.hidden_tasks(_tree)
	var collapsed := BehaviorGraphOps.get_collapsed(_tree)
	for task in BehaviorGraphOps.graph_tasks(_tree):
		if hidden.has(task):
			continue
		var node := NodeView.new()
		node.name = "t%d" % task.id
		node.position_offset = task.graph_position
		var has_output := task is BehaviorParent and (task as BehaviorParent).max_children() > 0
		var folded := 0
		if collapsed.has(task.id) and task is BehaviorParent:
			folded = BehaviorGraphOps.collect_subtree(task).size() - 1
		node.setup(task, has_output, folded, _tooltip_for(task))
		node.activated.connect(_on_node_activated)
		node.context_requested.connect(_on_node_context)
		_graph.add_child(node)
		_nodes[task] = node
		_task_by_name[node.name] = task


func _build_connections() -> void:
	if _tree.root and _nodes.has(_tree.root):
		_graph.connect_node(ENTRY_NAME, 0, _nodes[_tree.root].name, 0)
	for task: BehaviorTask in _nodes:
		if task is BehaviorParent and not BehaviorGraphOps.get_collapsed(_tree).has(task.id):
			for child in (task as BehaviorParent).children:
				if child and _nodes.has(child):
					_graph.connect_node(_nodes[task].name, 0, _nodes[child].name, 0)


func _tooltip_for(task: BehaviorTask) -> String:
	var script: Script = task.get_script()
	var text := "%s\n%s" % [BehaviorTask.get_type_name(script), BehaviorTaskCatalog.get_doc(script)]
	var warnings := task.get_warnings()
	if not warnings.is_empty():
		text += "\n\nProblems:\n" + "\n".join(warnings)
	return text.strip_edges()


func _apply_runtime() -> void:
	for task: BehaviorTask in _nodes:
		_nodes[task].set_runtime(_runtime_states.get(task.id, {}))


func _apply_links() -> void:
	for task: BehaviorTask in _nodes:
		_nodes[task].set_linked(false)
	var selected := _selected_tasks()
	if selected.size() == 1:
		for linked in BehaviorGraphOps.get_linked_tasks(selected[0]):
			if _nodes.has(linked):
				_nodes[linked].set_linked(true)


func _refresh_issues() -> void:
	_issues = _tree.validate() if _tree else ([] as Array[Dictionary])
	_issues_button.text = "⚠ %d" % _issues.size()
	_issue_list.clear()
	for issue in _issues:
		var task: BehaviorTask = issue["task"]
		var prefix := "%s: " % task.get_display_name() if task else ""
		_issue_list.add_item(prefix + String(issue["message"]))

#endregion

#region Selection and focus

func _selected_tasks() -> Array[BehaviorTask]:
	var out: Array[BehaviorTask] = []
	for task: BehaviorTask in _nodes:
		if _nodes[task].selected:
			out.append(task)
	return out


func _selected_frame_ids() -> Array[int]:
	var out: Array[int] = []
	for id: int in _frame_nodes:
		if _frame_nodes[id].selected:
			out.append(id)
	return out


func _queue_selection() -> void:
	if _rebuilding or _selection_queued:
		return
	_selection_queued = true
	_update_selection.call_deferred()


func _update_selection() -> void:
	_selection_queued = false
	if _tree == null:
		return
	_apply_links()
	var selected := _selected_tasks()
	if not selected.is_empty():
		_inspect(selected.back())
	else:
		_inspect(_tree)


func _inspect(object: Object) -> void:
	if object and is_visible_in_tree():
		EditorInterface.inspect_object(object)


func _on_node_selected(node: Node) -> void:
	if _rebuilding:
		return
	if not _link_mode.is_empty() and node is NodeView and node.task:
		_finish_link(node.task)
		return
	_queue_selection()


func _focus_task(task: BehaviorTask) -> void:
	if not _nodes.has(task):
		return
	for child in _graph.get_children():
		if child is GraphElement:
			child.selected = false
	var node: GraphElement = _nodes[task]
	node.selected = true
	_graph.scroll_offset = node.position_offset * _graph.zoom - (_graph.size - node.size * _graph.zoom) * 0.5
	_queue_selection()


func _on_issue_selected(index: int) -> void:
	if index < 0 or index >= _issues.size():
		return
	var task: BehaviorTask = _issues[index]["task"]
	if task:
		_focus_task(task)
	else:
		_inspect(_tree)


func _graph_position_of(local_position: Vector2) -> Vector2:
	return (local_position + _graph.scroll_offset) / _graph.zoom


func _mouse_graph_position() -> Vector2:
	var local := _graph.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, _graph.size).has_point(local):
		local = _graph.size * 0.5
	return _graph_position_of(local)


func _free_spot(position: Vector2) -> Vector2:
	var spot := position
	var occupied := true
	var guard := 0
	while occupied and guard < 40:
		occupied = false
		for task: BehaviorTask in _nodes:
			if task.graph_position.distance_to(spot) < 20.0:
				occupied = true
				spot += Vector2(30, 30)
				break
		guard += 1
	return spot

#endregion

#region Graph events

func _on_connection_request(from: StringName, _from_port: int, to: StringName, _to_port: int) -> void:
	var child: BehaviorTask = _task_by_name.get(to)
	if child == null:
		return
	if from == ENTRY_NAME:
		commit("Set Root", func() -> void: BehaviorGraphOps.set_root(_tree, child))
		return
	var parent: BehaviorTask = _task_by_name.get(from)
	if not BehaviorGraphOps.can_connect(parent, child):
		return
	var linked := [false]
	commit("Connect Tasks", func() -> void: linked[0] = BehaviorGraphOps.connect_tasks(_tree, parent, child))
	if not linked[0]:
		push_warning("Behaviors: %s accepts at most %d children." % [parent.get_display_name(), (parent as BehaviorParent).max_children()])


func _on_disconnection_request(_from: StringName, _from_port: int, to: StringName, _to_port: int) -> void:
	var child: BehaviorTask = _task_by_name.get(to)
	if child:
		commit("Disconnect Task", func() -> void: BehaviorGraphOps.disconnect_task(_tree, child))


func _on_connection_to_empty(from: StringName, _from_port: int, release_position: Vector2) -> void:
	_pending_link = {"from": from, "position": _graph_position_of(release_position)}
	_quick.open_at(Vector2i(DisplayServer.mouse_get_position()))


func _on_connection_from_empty(to: StringName, _to_port: int, release_position: Vector2) -> void:
	_pending_link = {"to": to, "position": _graph_position_of(release_position) - Vector2(BehaviorGraphOps.DEFAULT_SIZE.x + 40.0, 0.0)}
	_quick.open_at(Vector2i(DisplayServer.mouse_get_position()), true)


func _on_delete_nodes_request(names: Array[StringName]) -> void:
	var tasks: Array[BehaviorTask] = []
	var frame_ids: Array[int] = []
	for node_name in names:
		if _task_by_name.has(node_name):
			tasks.append(_task_by_name[node_name])
		elif String(node_name).begins_with("f"):
			frame_ids.append(int(String(node_name).substr(1)))
	if tasks.is_empty() and frame_ids.is_empty():
		return
	commit("Delete", func() -> void:
		BehaviorGraphOps.delete_tasks(_tree, tasks)
		var frames: Array = []
		for frame: Dictionary in BehaviorGraphOps.get_frames(_tree):
			if not frame_ids.has(int(frame["id"])):
				frames.append(frame)
		BehaviorGraphOps.set_frames(_tree, frames))


func _delete_selected() -> void:
	var names: Array[StringName] = []
	for child in _graph.get_children():
		if child is GraphElement and child.selected and child.name != ENTRY_NAME:
			names.append(child.name)
	_on_delete_nodes_request(names)


func _on_popup_request(at_position: Vector2) -> void:
	_context_position = _graph_position_of(at_position)
	_show_menu()


func _on_node_context(node: GraphElement) -> void:
	if node.name != ENTRY_NAME and not node.selected:
		for child in _graph.get_children():
			if child is GraphElement:
				child.selected = false
		node.selected = true
		_queue_selection()
	_context_position = _mouse_graph_position()
	_show_menu()


func _on_frame_input(event: InputEvent, frame: GraphFrame) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT and button.double_click:
		_ask_text("Frame Title", frame.title, func(text: String) -> void:
			frame.title = text
			_sync_layout("Rename Frame"))
	elif button.button_index == MOUSE_BUTTON_RIGHT:
		frame.accept_event()
		_context_position = _mouse_graph_position()
		_show_menu()


func _on_graph_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE and not _link_mode.is_empty():
		_end_link_mode()
		_graph.accept_event()
	elif key.keycode == KEY_SPACE and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed:
		_pending_link = {"position": _mouse_graph_position()}
		_quick.open_at(Vector2i(DisplayServer.mouse_get_position()))
		_graph.accept_event()


func _on_node_activated(node: Node) -> void:
	var task: BehaviorTask = node.task
	if task is BehaviorSubtree and (task as BehaviorSubtree).tree:
		open_tree((task as BehaviorSubtree).tree)
	elif task:
		_rename_task(task)


func _sync_layout(action_name: String) -> void:
	if _tree == null:
		return
	var moved: Array[BehaviorTask] = []
	commit(action_name, func() -> void:
		for task: BehaviorTask in _nodes:
			var node: GraphElement = _nodes[task]
			if node.position_offset != task.graph_position:
				task.graph_position = node.position_offset
				moved.append(task)
		if _entry:
			_tree.editor_data[BehaviorGraphOps.KEY_ENTRY] = _entry.position_offset
		if not _frame_nodes.is_empty():
			var frames: Array = []
			for id: int in _frame_nodes:
				var frame: GraphFrame = _frame_nodes[id]
				frames.append({"id": id, "title": frame.title, "color": frame.tint_color, "rect": Rect2(frame.position_offset, frame.size)})
			BehaviorGraphOps.set_frames(_tree, frames)
		BehaviorGraphOps.sort_around(_tree, moved), false)

#endregion

#region Adding

func _on_palette_activated(entry: Dictionary) -> void:
	_pending_link = {}
	var center := _graph_position_of(_graph.size * 0.5)
	_add_entry(entry, _free_spot(center))


func _on_quick_chosen(entry: Dictionary) -> void:
	var link := _pending_link
	_pending_link = {}
	_add_entry(entry, link.get("position", _mouse_graph_position()), link)


func _add_entry(entry: Dictionary, position: Vector2, link: Dictionary = {}) -> void:
	if _tree == null:
		return
	var script: Script = entry["script"]
	var task: BehaviorTask = script.new()
	commit("Add %s" % entry["name"], func() -> void:
		if link.has("to"):
			var child: BehaviorTask = _task_by_name.get(link["to"])
			BehaviorGraphOps.add_task(_tree, task, position)
			if child and task is BehaviorParent:
				BehaviorGraphOps.connect_tasks(_tree, task, child)
		else:
			var parent: BehaviorTask = _task_by_name.get(link.get("from", &""))
			BehaviorGraphOps.add_task(_tree, task, position, parent)
			if link.get("from", &"") == ENTRY_NAME and _tree.root != task:
				BehaviorGraphOps.set_root(_tree, task))
	_pending_select = [StringName("t%d" % task.id)]
	_inspect_pending = true
	_queue_refresh()


func _can_drop_on_graph(_at: Vector2, data: Variant) -> bool:
	if _tree == null or not (data is Dictionary):
		return false
	if data.get("type", "") == Palette.DRAG_TYPE:
		return true
	if data.get("type", "") == "files":
		for path: String in data.get("files", []):
			if ResourceLoader.exists(path) and load(path) is BehaviorTree:
				return true
	return false


func _drop_on_graph(at: Vector2, data: Variant) -> void:
	var position := _graph_position_of(at)
	_pending_link = {}
	if data.get("type", "") == Palette.DRAG_TYPE:
		for entry in BehaviorTaskCatalog.get_entries():
			if entry["class_name"] == data["class_name"]:
				_add_entry(entry, position)
				return
	elif data.get("type", "") == "files":
		for path: String in data.get("files", []):
			var dropped := load(path) as BehaviorTree
			if dropped and dropped != _tree:
				var subtree := BehaviorSubtree.new()
				subtree.tree = dropped
				subtree.label = path.get_file().get_basename().capitalize()
				commit("Add Subtree", func() -> void: BehaviorGraphOps.add_task(_tree, subtree, position))
				position += Vector2(30, 30)


func _add_frame() -> void:
	var rect := Rect2(_mouse_graph_position(), Vector2(320, 200))
	var selected := _selected_tasks()
	if not selected.is_empty():
		var bounds := Rect2(selected[0].graph_position, _nodes[selected[0]].size)
		for task in selected:
			bounds = bounds.merge(Rect2(task.graph_position, _nodes[task].size))
		rect = bounds.grow(24.0)
		rect.position.y -= 24.0
	commit("Add Frame", func() -> void:
		var frames := BehaviorGraphOps.get_frames(_tree)
		frames.append({"id": BehaviorGraphOps.next_frame_id(_tree), "title": "Comment", "color": Color(0.3, 0.45, 0.7, 0.3), "rect": rect})
		BehaviorGraphOps.set_frames(_tree, frames))

#endregion

#region Context menu and actions

func _show_menu() -> void:
	if _tree == null:
		return
	var selected := _selected_tasks()
	_menu.reset()
	var add_menu := _menu.add_submenu("Add Task")
	var folders := {}
	for entry in BehaviorTaskCatalog.get_entries():
		var parent := add_menu
		var key := ""
		for part in entry["category"]:
			key += "/" + part
			if not folders.has(key):
				folders[key] = _menu.add_submenu(part, parent)
			parent = folders[key]
		_menu.add_action(entry["name"], _add_from_menu.bind(entry, _context_position), true, parent)
	_menu.add_separator()
	if not selected.is_empty():
		var single: BehaviorTask = selected[0] if selected.size() == 1 else null
		_menu.add_action("Rename...", _rename_task.bind(selected.back()), single != null)
		_menu.add_action("Copy", _copy_selected)
		_menu.add_action("Duplicate", _duplicate_selected)
		_menu.add_action("Delete", _delete_selected)
		_menu.add_separator()
		var all_disabled := true
		var all_breakpoints := true
		for task in selected:
			all_disabled = all_disabled and task.disabled
			all_breakpoints = all_breakpoints and task.breakpoint_enabled
		_menu.add_action("Enable" if all_disabled else "Disable", _set_disabled.bind(selected, not all_disabled))
		_menu.add_action("Remove Breakpoint" if all_breakpoints else "Add Breakpoint", _set_breakpoint.bind(selected, not all_breakpoints))
		if single is BehaviorParent and (single as BehaviorParent).max_children() > 0:
			var folded := BehaviorGraphOps.get_collapsed(_tree).has(single.id)
			_menu.add_action("Expand Subtree" if folded else "Collapse Subtree", _toggle_collapse.bind(single))
		if single is BehaviorSubtree:
			_menu.add_action("Open Subtree", _open_subtree.bind(single), (single as BehaviorSubtree).tree != null)
		_menu.add_action("Disconnect From Parent", _disconnect_tasks.bind(selected))
		_menu.add_action("Export as Subtree...", _ask_file.bind("export"), single != null)
		_menu.add_separator()
	_menu.add_action("Paste", _paste, not _clipboard.is_empty())
	_menu.add_action("Add Frame", _add_frame)
	_menu.add_action("Arrange", _arrange)
	_menu.popup_at_mouse()


func _add_from_menu(entry: Dictionary, position: Vector2) -> void:
	_pending_link = {}
	_add_entry(entry, position)


func _set_disabled(tasks: Array[BehaviorTask], value: bool) -> void:
	commit("Toggle Disabled", func() -> void:
		for task in tasks:
			task.disabled = value)


func _set_breakpoint(tasks: Array[BehaviorTask], value: bool) -> void:
	commit("Toggle Breakpoint", func() -> void:
		for task in tasks:
			task.breakpoint_enabled = value)


func _disconnect_tasks(tasks: Array[BehaviorTask]) -> void:
	commit("Disconnect Tasks", func() -> void:
		for task in tasks:
			BehaviorGraphOps.disconnect_task(_tree, task))


func _open_subtree(task: BehaviorSubtree) -> void:
	if task.tree:
		open_tree(task.tree)


func _copy_selected() -> void:
	var selected := _selected_tasks()
	if not selected.is_empty():
		_clipboard = BehaviorGraphOps.copy_tasks(_tree, selected)


func _paste() -> void:
	if _clipboard.is_empty() or _tree == null:
		return
	var origin := _mouse_graph_position()
	var added: Array[BehaviorTask] = []
	commit("Paste Tasks", func() -> void: added.assign(BehaviorGraphOps.place_copies(_tree, _clipboard, origin)))
	_select_added(added)


func _duplicate_selected() -> void:
	var selected := _selected_tasks()
	if selected.is_empty():
		return
	var copies := BehaviorGraphOps.copy_tasks(_tree, selected)
	var corner := Vector2(INF, INF)
	for copy in copies:
		corner = Vector2(minf(corner.x, copy.graph_position.x), minf(corner.y, copy.graph_position.y))
	var added: Array[BehaviorTask] = []
	commit("Duplicate Tasks", func() -> void: added.assign(BehaviorGraphOps.place_copies(_tree, copies, corner + Vector2(40, 40))))
	_select_added(added)


func _select_added(added: Array[BehaviorTask]) -> void:
	_pending_select = []
	for task in added:
		_pending_select.append(StringName("t%d" % task.id))
	_inspect_pending = true
	_queue_refresh()


func _toggle_collapse(task: BehaviorTask) -> void:
	commit("Toggle Collapse", func() -> void:
		var ids := BehaviorGraphOps.get_collapsed(_tree)
		if ids.has(task.id):
			ids.erase(task.id)
		else:
			ids.append(task.id)
		BehaviorGraphOps.set_collapsed(_tree, ids))


func _rename_task(task: BehaviorTask) -> void:
	_ask_text("Rename Task", task.label if not task.label.is_empty() else task.get_display_name(), func(text: String) -> void:
		var new_label := text.strip_edges()
		if new_label == BehaviorTask.get_type_name(task.get_script()):
			new_label = ""
		commit("Rename Task", func() -> void: task.label = new_label))


func _ask_text(title: String, initial: String, callback: Callable) -> void:
	_prompt.title = title
	_prompt_edit.text = initial
	_prompt_callback = callback
	_prompt.popup_centered(Vector2i(320, 100))
	_prompt_edit.grab_focus()
	_prompt_edit.select_all()


func _arrange() -> void:
	if _tree == null:
		return
	var sizes := {}
	for task: BehaviorTask in _nodes:
		sizes[task] = _nodes[task].size
	var collapsed := {}
	for task: BehaviorTask in _nodes:
		if BehaviorGraphOps.get_collapsed(_tree).has(task.id):
			collapsed[task] = true
	commit("Arrange Tasks", func() -> void: BehaviorGraphOps.arrange(_tree, sizes, collapsed))


func _end_link_mode() -> void:
	_link_mode = {}
	_link_label.visible = false


func _finish_link(target: BehaviorTask) -> void:
	var source: BehaviorTask = _link_mode["task"]
	var property: StringName = _link_mode["property"]
	var required: String = _link_mode["class"]
	if not BehaviorTaskCatalog.script_is_a(target.get_script(), required):
		_link_label.text = "%s is not a %s. Pick another, or press Esc." % [target.get_display_name(), required]
		_apply_selection_of(source)
		return
	_end_link_mode()
	commit("Link Task", func() -> void: BehaviorGraphOps.link_task(source, property, target))
	_pending_select = [StringName("t%d" % source.id)]
	_inspect_pending = true
	_queue_refresh()


func _apply_selection_of(task: BehaviorTask) -> void:
	_rebuilding = true
	for child in _graph.get_children():
		if child is GraphElement:
			child.selected = _nodes.get(task) == child
	_rebuilding = false

#endregion

#region Files and saving

func _ask_file(mode: String) -> void:
	_file_mode = mode
	match mode:
		"new":
			_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
			_file_dialog.title = "New Behavior Tree"
			_file_dialog.current_file = "new_tree.tres"
		"open":
			_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
			_file_dialog.title = "Open Behavior Tree"
		"export":
			_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
			_file_dialog.title = "Export Subtree"
			_file_dialog.current_file = "subtree.tres"
	_file_dialog.popup_file_dialog()


func _on_file_selected(path: String) -> void:
	match _file_mode:
		"new":
			var fresh := BehaviorGraphOps.new_tree()
			fresh.take_over_path(path)
			if ResourceSaver.save(fresh, path) != OK:
				push_error("Behaviors: Could not save %s." % path)
				return
			EditorInterface.get_resource_filesystem().update_file(path)
			_agent = null
			open_tree(fresh)
		"open":
			var loaded := load(path) as BehaviorTree
			if loaded == null:
				push_error("Behaviors: %s is not a behavior tree." % path)
				return
			_agent = null
			open_tree(loaded)
		"export":
			_export_subtree(path)


func _export_subtree(path: String) -> void:
	var selected := _selected_tasks()
	if selected.size() != 1:
		return
	var task := selected[0]
	var failed := [false]
	commit("Export Subtree", func() -> void:
		var result := BehaviorGraphOps.extract_subtree(_tree, task)
		if result.is_empty():
			failed[0] = true
			return
		var exported: BehaviorTree = result["tree"]
		exported.take_over_path(path)
		if ResourceSaver.save(exported, path) != OK:
			push_error("Behaviors: Could not save %s." % path)
		EditorInterface.get_resource_filesystem().update_file(path))
	if failed[0]:
		push_error("Behaviors: Could not export the subtree.")


func _is_file_backed() -> bool:
	return _tree != null and not _tree.resource_path.is_empty() and not "::" in _tree.resource_path


func _mark_modified() -> void:
	if _tree == null:
		return
	_tree.emit_changed()
	if _is_file_backed():
		if _auto_save.button_pressed:
			_save_timer.start()
	else:
		EditorInterface.mark_scene_as_unsaved()


func _save_now(force := false) -> void:
	_save_timer.stop()
	if _tree == null:
		return
	if _is_file_backed():
		var error := ResourceSaver.save(_tree, _tree.resource_path)
		if error != OK:
			push_error("Behaviors: Could not save %s (error %d)." % [_tree.resource_path, error])
	elif force:
		EditorInterface.save_scene()


func _after_change(rebuild: bool) -> void:
	if rebuild:
		_queue_refresh()
	else:
		_refresh_issues()
	_mark_modified()


func _restore(tree: BehaviorTree, state: Dictionary) -> void:
	BehaviorGraphOps.restore(tree, state)
	if tree == _tree:
		_after_change(true)
	else:
		tree.emit_changed()


func _owns(object: Object) -> bool:
	if _tree == null or object == null:
		return false
	if object == _tree:
		return true
	if object is BehaviorTask:
		return _tree.get_tasks(true).has(object)
	if object is BehaviorVariable:
		return _tree.variables.has(object)
	return false


func _on_property_edited(_property: String) -> void:
	if _owns(EditorInterface.get_inspector().get_edited_object()):
		_queue_refresh()
		_mark_modified()


func _on_version_changed() -> void:
	if _agent and is_instance_valid(_agent) and _agent.tree != _tree:
		edit_object(_agent)
		return
	if _tree != null and is_visible_in_tree():
		_queue_refresh()


func _on_visibility_changed() -> void:
	if visible and _tree != null:
		_queue_refresh()


func _on_script_classes_updated() -> void:
	BehaviorTaskCatalog.refresh()
	_palette.rebuild()

#endregion
