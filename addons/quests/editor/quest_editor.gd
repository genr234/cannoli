@tool
extends VBoxContainer
## The Quests main screen: a graph canvas for the selected quest, a list of the
## quests in the open database, an outline of the quest's info, counters,
## conditions and states, and a list of problems found by the validator.

const QuestGraphNode := preload("quest_graph_node.gd")
const QuestFormDialog := preload("quest_form_dialog.gd")
const QuestContext := preload("quest_context.gd")
const QuestDescribe := preload("quest_describe.gd")
const DebuggerPlugin := preload("debugger_plugin.gd")
const QuestActionMenu := preload("quest_action_menu.gd")
const QuestOutline := preload("quest_outline.gd")
const QuestFileActions := preload("quest_file_actions.gd")
const QuestReferenceDialog := preload("quest_reference_dialog.gd")
const QuestRelationsView := preload("quest_relations_view.gd")

const SETTING_AUTO_SAVE := "quests/editor/auto_save"

enum Menu {
	NEW_QUEST, NEW_FROM_TEMPLATE, OPEN_FILE, ADD_EXISTING, DUPLICATE_QUEST, REMOVE_QUEST, SORT_ID, SORT_TITLE,
	NODE_PASSTHROUGH, NODE_CONDITION, NODE_SUCCESS, NODE_FAILURE,
	TYPE_PASSTHROUGH, TYPE_CONDITION, TYPE_SUCCESS, TYPE_FAILURE,
	CLEAR_CONNECTIONS, DELETE_NODES, COPY_NODES, PASTE_NODES, DUPLICATE_NODES, ARRANGE, ARRANGE_SELECTED,
	WIZARD_MESSAGE, WIZARD_COUNTER, WIZARD_RETURN, EXPORT_JSON, IMPORT_JSON, ADD_FROM_SCENE,
	TEMPLATE_BASE = 100,
}

var context: QuestContext
var undo_redo: EditorUndoRedoManager
var debugger: DebuggerPlugin

var _quest: Quest
var _source: Object
var _source_property := ""
var _loose_quests: Array[Quest] = []
var _selected_ids: Array[String] = []
var _clipboard: Array = []
var _issues: Array[Dictionary] = []
var _runtime: Dictionary = {}
var _runtime_list_id := ""
var _show_relations := false
var _refresh_queued := false
var _dirty := false
var _context_node_id := ""
var _context_position := Vector2.ZERO

var _toolbar := HBoxContainer.new()
var _source_label := Label.new()
var _new_button := MenuButton.new()
var _node_button := MenuButton.new()
var _wizard_button := MenuButton.new()
var _save_button := Button.new()
var _auto_save := CheckBox.new()
var _arrange_button := Button.new()
var _relations_button := Button.new()
var _reference_button := Button.new()
var _runtime_label := Label.new()
var _split := HSplitContainer.new()
var _quest_list := ItemList.new()
var _list_buttons := HBoxContainer.new()
var _graph := GraphEdit.new()
var _problems := ItemList.new()
var _empty_label := Label.new()
var _outline := QuestOutline.new()
var _context_menu := QuestActionMenu.new()
var _form := QuestFormDialog.new()
var _file_dialog := EditorFileDialog.new()
var _files: QuestFileActions
var _remove_dialog := ConfirmationDialog.new()
var _runtime_row := HBoxContainer.new()
var _runtime_state := OptionButton.new()
var _reference_dialog: QuestReferenceDialog
var _save_timer := Timer.new()
var _rebuilding := false


func _init() -> void:
	name = "Quests"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _ready() -> void:
	_build_ui()
	_build_dialogs()
	_refresh_all()
	var inspector := EditorInterface.get_inspector()
	inspector.property_edited.connect(_on_property_edited)
	if undo_redo != null:
		undo_redo.version_changed.connect(_queue_refresh)
	visibility_changed.connect(_on_visibility_changed)


func _exit_tree() -> void:
	if debugger != null:
		debugger.set_editor_watching(false)


# ---------------------------------------------------------------- public API

## Opens a quest, a database or a quest list (a node with a `quests` array).
func edit_object(object: Object) -> void:
	if object is QuestDatabase:
		_set_source(object, "quest_assets")
		var first := _get_source_quests().front() if not _get_source_quests().is_empty() else null
		_set_quest(first)
	elif object is QuestList:
		_set_source(object, "quests")
		var first := _get_source_quests().front() if not _get_source_quests().is_empty() else null
		_set_quest(first)
	elif object is Quest:
		if not _get_source_quests().has(object):
			_set_source(null, "")
			_loose_quests = [object]
		_set_quest(object)


func get_quest() -> Quest:
	return _quest


## Called with each snapshot from the debugger. Highlights the live states of
## the open quest when it is running.
func on_runtime_state(data: Dictionary) -> void:
	_runtime = {}
	_runtime_list_id = ""
	if _quest != null:
		for list: Dictionary in data.get("lists", []):
			for quest: Dictionary in list.get("quests", []):
				if quest.get("id", "") == _quest.id:
					_runtime = quest
					_runtime_list_id = list.get("id", "")
					break
			if not _runtime.is_empty():
				break
	_apply_runtime()


func on_session_stopped() -> void:
	_runtime = {}
	_apply_runtime()


# ------------------------------------------------------------------------ UI

func _build_ui() -> void:
	_build_toolbar()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_split)
	_split.add_child(_build_quest_list())
	var center_split := HSplitContainer.new()
	center_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.add_child(center_split)
	center_split.add_child(_build_center())
	_outline.commit_requested.connect(_commit)
	_outline.refresh_requested.connect(_queue_refresh)
	center_split.add_child(_outline)


func _build_toolbar() -> void:
	_toolbar.add_theme_constant_override("separation", 6)
	add_child(_toolbar)
	_source_label.text = "No quest open"
	_source_label.add_theme_font_size_override("font_size", 14)
	_toolbar.add_child(_source_label)
	_toolbar.add_child(VSeparator.new())
	_build_new_menu()
	_build_node_menu()
	_build_wizard_menu()
	_arrange_button.text = "Arrange"
	_arrange_button.tooltip_text = "Lay out the nodes in levels. With nodes selected, arranges only those."
	_arrange_button.pressed.connect(func() -> void: _arrange(false))
	_toolbar.add_child(_arrange_button)
	_relations_button.text = "Relations"
	_relations_button.toggle_mode = true
	_relations_button.tooltip_text = "Show how the quests in the list refer to each other."
	_relations_button.toggled.connect(func(pressed: bool) -> void:
		_show_relations = pressed
		_rebuild_graph())
	_toolbar.add_child(_relations_button)
	_reference_button.text = "Reference"
	_reference_button.tooltip_text = "Copy tags and messages to the clipboard."
	_reference_button.pressed.connect(_show_reference)
	_toolbar.add_child(_reference_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toolbar.add_child(spacer)
	_runtime_label.add_theme_color_override("font_color", Color("f2c14e"))
	_toolbar.add_child(_runtime_label)
	_auto_save.text = "Auto-save"
	_auto_save.tooltip_text = "Save the quest file after every change."
	_auto_save.button_pressed = ProjectSettings.get_setting(SETTING_AUTO_SAVE, true)
	_auto_save.toggled.connect(func(pressed: bool) -> void: ProjectSettings.set_setting(SETTING_AUTO_SAVE, pressed))
	_toolbar.add_child(_auto_save)
	_save_button.text = "Save"
	_save_button.pressed.connect(func() -> void: _save_quest(true))
	_toolbar.add_child(_save_button)


func _build_new_menu() -> void:
	_setup_menu_button(_new_button, "New", "Add")
	var popup := _new_button.get_popup()
	popup.add_item("New Quest...", Menu.NEW_QUEST)
	var templates := PopupMenu.new()
	templates.name = "templates"
	popup.add_child(templates)
	var template_ids := QuestWizards.get_templates().keys()
	for index in template_ids.size():
		templates.add_item(QuestWizards.get_templates()[template_ids[index]].title, Menu.TEMPLATE_BASE + index)
	templates.id_pressed.connect(func(id: int) -> void: _files.new_from_template(String(template_ids[id - Menu.TEMPLATE_BASE])))
	popup.add_submenu_node_item("New From Template", templates, Menu.NEW_FROM_TEMPLATE)
	popup.add_separator()
	popup.add_item("Add Existing Quest...", Menu.ADD_EXISTING)
	popup.add_item("Add Quests From Open Scene", Menu.ADD_FROM_SCENE)
	popup.id_pressed.connect(_on_toolbar_menu)


func _build_node_menu() -> void:
	_setup_menu_button(_node_button, "Add Node", "New")
	var popup := _node_button.get_popup()
	popup.add_item("Passthrough", Menu.NODE_PASSTHROUGH)
	popup.add_item("Condition", Menu.NODE_CONDITION)
	popup.add_item("Success", Menu.NODE_SUCCESS)
	popup.add_item("Failure", Menu.NODE_FAILURE)
	popup.id_pressed.connect(_on_toolbar_menu)


func _build_wizard_menu() -> void:
	_setup_menu_button(_wizard_button, "Wizards", "Tools")
	var popup := _wizard_button.get_popup()
	popup.add_item("Counter Requirement...", Menu.WIZARD_COUNTER)
	popup.add_item("Message Requirement...", Menu.WIZARD_MESSAGE)
	popup.add_item("Return to Quest Giver...", Menu.WIZARD_RETURN)
	popup.add_separator()
	popup.add_item("Export Quest to JSON...", Menu.EXPORT_JSON)
	popup.add_item("Import Quest from JSON...", Menu.IMPORT_JSON)
	popup.id_pressed.connect(_on_toolbar_menu)


func _setup_menu_button(button: MenuButton, text: String, icon_name: String) -> void:
	button.text = text
	button.flat = false
	button.icon = EditorInterface.get_editor_theme().get_icon(icon_name, "EditorIcons")
	_toolbar.add_child(button)


func _build_quest_list() -> Control:
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 190
	var left_title := Label.new()
	left_title.text = "Quests"
	left.add_child(left_title)
	_quest_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_list.item_selected.connect(_on_quest_list_selected)
	left.add_child(_quest_list)
	var duplicate_button := Button.new()
	duplicate_button.text = "Duplicate"
	duplicate_button.pressed.connect(func() -> void: _on_toolbar_menu(Menu.DUPLICATE_QUEST))
	var remove_button := Button.new()
	remove_button.text = "Remove"
	remove_button.pressed.connect(func() -> void: _on_toolbar_menu(Menu.REMOVE_QUEST))
	var sort_button := MenuButton.new()
	sort_button.text = "Sort"
	sort_button.flat = false
	sort_button.get_popup().add_item("By ID", Menu.SORT_ID)
	sort_button.get_popup().add_item("By Title", Menu.SORT_TITLE)
	sort_button.get_popup().id_pressed.connect(_on_toolbar_menu)
	for button in [duplicate_button, remove_button, sort_button]:
		_list_buttons.add_child(button)
	left.add_child(_list_buttons)
	return left


## The graph canvas with the runtime state row and the problem list under it.
func _build_center() -> Control:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var graph_holder := Control.new()
	graph_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(graph_holder)
	_setup_graph()
	graph_holder.add_child(_graph)
	_empty_label.text = "Select a Quest or QuestDatabase resource, or use New > New Quest."
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_empty_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	graph_holder.add_child(_empty_label)
	_build_runtime_row()
	center.add_child(_runtime_row)
	_problems.custom_minimum_size.y = 90
	_problems.item_selected.connect(_on_problem_selected)
	center.add_child(_problems)
	return center


func _setup_graph() -> void:
	_graph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_graph.right_disconnects = true
	_graph.show_arrange_button = false
	_graph.minimap_enabled = true
	_graph.connection_request.connect(_on_connection_request)
	_graph.disconnection_request.connect(_on_disconnection_request)
	_graph.delete_nodes_request.connect(_on_delete_nodes_request)
	_graph.node_selected.connect(_on_node_selected)
	_graph.node_deselected.connect(_on_node_deselected)
	_graph.end_node_move.connect(_on_end_node_move)
	_graph.popup_request.connect(_on_popup_request)
	_graph.copy_nodes_request.connect(_copy_selected)
	_graph.cut_nodes_request.connect(func() -> void:
		_copy_selected()
		_on_delete_nodes_request(_selected_graph_names()))
	_graph.paste_nodes_request.connect(_paste)
	_graph.duplicate_nodes_request.connect(_duplicate_selected)


func _build_runtime_row() -> void:
	_runtime_row.visible = false
	var runtime_title := Label.new()
	runtime_title.text = "Running quest state:"
	_runtime_row.add_child(runtime_title)
	for state_name: String in Quest.State.keys():
		_runtime_state.add_item(state_name.capitalize())
	_runtime_row.add_child(_runtime_state)
	var apply := Button.new()
	apply.text = "Set"
	apply.pressed.connect(func() -> void:
		if debugger != null and not _runtime.is_empty():
			debugger.send_command("quests:set_state", [_runtime_list_id, _quest.id, _runtime_state.selected]))
	_runtime_row.add_child(apply)


func _build_dialogs() -> void:
	for dialog: Node in [_form, _remove_dialog, _file_dialog, _context_menu, _save_timer]:
		add_child(dialog)
	_files = QuestFileActions.new(_file_dialog, _form, context, get_quest)
	_files.quest_ready.connect(_add_to_source)
	_files.object_chosen.connect(edit_object)
	_remove_dialog.title = "Remove Quest"
	_remove_dialog.ok_button_text = "Remove Reference"
	_remove_dialog.add_button("Delete File", true, "delete_file")
	_remove_dialog.confirmed.connect(func() -> void: _remove_current_quest(false))
	_remove_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == "delete_file":
			_remove_dialog.hide()
			_remove_current_quest(true))
	_file_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_file_dialog.add_filter("*.tres", "Quest resource")
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.5
	_save_timer.timeout.connect(func() -> void: _save_quest(false))


# ----------------------------------------------------------- source and quest

func _get_source_quests() -> Array[Quest]:
	if _source != null and not _source_property.is_empty() and is_instance_valid(_source):
		var typed: Array[Quest] = []
		typed.assign(_source.get(_source_property))
		return typed
	return _loose_quests


func _set_source(source: Object, property: String) -> void:
	_source = source
	_source_property = property
	_loose_quests = []
	context.source_quests = _get_source_quests()


func _set_quest(quest: Quest) -> void:
	if _quest != null and _quest.changed.is_connected(_queue_refresh):
		_quest.changed.disconnect(_queue_refresh)
	_quest = quest
	if _quest != null:
		QuestGraphOps.ensure_state_infos(_quest)
		_quest.changed.connect(_queue_refresh)
	_selected_ids.clear()
	_runtime = {}
	context.current_quest = quest
	context.source_quests = _get_source_quests()
	_refresh_all()
	if debugger != null:
		debugger.set_editor_watching(is_visible_in_tree() and quest != null)
		var last := debugger.get_last_state()
		if not last.is_empty():
			on_runtime_state(last)


func _set_source_quests(quests: Array[Quest], action_name: String) -> void:
	if _source == null:
		_loose_quests = quests
		context.source_quests = quests
		_refresh_list()
		return
	var old: Array[Quest] = _get_source_quests().duplicate()
	if undo_redo != null:
		undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, _source)
		undo_redo.add_do_property(_source, _source_property, quests)
		undo_redo.add_undo_property(_source, _source_property, old)
		undo_redo.add_do_method(self, "_after_source_changed")
		undo_redo.add_undo_method(self, "_after_source_changed")
		undo_redo.commit_action()
	else:
		_source.set(_source_property, quests)
		_after_source_changed()


func _after_source_changed() -> void:
	context.source_quests = _get_source_quests()
	if _source is QuestList:
		EditorInterface.mark_scene_as_unsaved()
	_refresh_list()


# ---------------------------------------------------------------- refreshing

func _refresh_all() -> void:
	if not is_node_ready():
		return
	_refresh_list()
	_rebuild_graph()
	_rebuild_outline()
	_update_title()


func _queue_refresh() -> void:
	_dirty = true
	if _refresh_queued or not is_node_ready():
		return
	_refresh_queued = true
	_refresh_deferred.call_deferred()


func _refresh_deferred() -> void:
	_refresh_queued = false
	_rebuild_graph()
	_rebuild_outline()
	_refresh_list()
	if _dirty and _auto_save.button_pressed and is_visible_in_tree() and _save_timer.is_inside_tree():
		_save_timer.start()


func _on_property_edited(_property: String) -> void:
	var object := EditorInterface.get_inspector().get_edited_object()
	if object is Resource and _quest != null:
		_queue_refresh()


func _on_visibility_changed() -> void:
	if debugger != null:
		debugger.set_editor_watching(is_visible_in_tree() and _quest != null)


func _update_title() -> void:
	if _quest == null:
		_source_label.text = "No quest open"
	elif _source is QuestDatabase:
		_source_label.text = "%s  >  %s" % [_source.resource_path.get_file() if not _source.resource_path.is_empty() else "Database", _quest.title if not _quest.title.is_empty() else _quest.id]
	else:
		_source_label.text = _quest.title if not _quest.title.is_empty() else _quest.id


func _refresh_list() -> void:
	_quest_list.clear()
	var quests := _get_source_quests()
	var ids := context.get_quest_ids()
	for index in quests.size():
		var quest := quests[index]
		if quest == null:
			_quest_list.add_item("(empty slot)")
			continue
		var problems := QuestValidator.validate(quest, ids)
		var text := quest.title if not quest.title.is_empty() else quest.id
		if not quest.id.is_empty() and text != quest.id:
			text += "  (%s)" % quest.id
		_quest_list.add_item(text)
		_quest_list.set_item_metadata(index, quest)
		_quest_list.set_item_tooltip(index, "\n".join(problems) if not problems.is_empty() else quest.resource_path)
		if not problems.is_empty():
			_quest_list.set_item_custom_fg_color(index, Color("e5b34b"))
		if quest == _quest:
			_quest_list.select(index)
	_list_buttons.visible = not quests.is_empty()


func _on_quest_list_selected(index: int) -> void:
	var quest: Quest = _quest_list.get_item_metadata(index)
	if quest == null:
		return
	if _show_relations:
		_relations_button.button_pressed = false
	_set_quest(quest)
	EditorInterface.edit_resource(quest)


# ------------------------------------------------------------------- canvas

func _rebuild_graph() -> void:
	if not is_node_ready():
		return
	_rebuilding = true
	_graph.clear_connections()
	for child in _graph.get_children():
		if child is GraphElement:
			_graph.remove_child(child)
			child.queue_free()
	_rebuild_graph_contents()
	_rebuilding = false


func _rebuild_graph_contents() -> void:
	_empty_label.visible = _quest == null
	_graph.visible = _quest != null
	if _quest == null:
		_problems.clear()
		return
	if _show_relations:
		_rebuild_relations()
		return
	_issues = QuestValidator.validate_issues(_quest, context.get_quest_ids())
	var by_node := {}
	for issue in _issues:
		if not issue.node_id.is_empty():
			by_node[issue.node_id] = by_node.get(issue.node_id, "") + issue.message + "\n"
	if _quest.node_list.size() > 1 and _all_at_origin():
		QuestGraphOps.arrange(_quest, [])
	for index in _quest.node_list.size():
		var node := _quest.node_list[index]
		if node == null:
			continue
		var graph_node := QuestGraphNode.new()
		graph_node.name = "n%d" % index
		graph_node.position_offset = node.editor_position
		graph_node.setup(node, String(by_node.get(node.id, "")).strip_edges())
		graph_node.selected = _selected_ids.has(node.id)
		_graph.add_child(graph_node)
	for index in _quest.node_list.size():
		var node := _quest.node_list[index]
		if node == null:
			continue
		for child_id in node.children:
			var child_index := QuestGraphOps.node_index(_quest, child_id)
			if child_index >= 0:
				_graph.connect_node("n%d" % index, 0, "n%d" % child_index, 0)
	_apply_runtime()
	_rebuild_problem_list()


func _all_at_origin() -> bool:
	for index in range(1, _quest.node_list.size()):
		if _quest.node_list[index] != null and not _quest.node_list[index].editor_position.is_zero_approx():
			return false
	return true


func _rebuild_problem_list() -> void:
	_problems.clear()
	if _issues.is_empty():
		_problems.add_item("No problems found.")
		_problems.set_item_disabled(0, true)
		return
	for issue in _issues:
		var index := _problems.add_item(("Error: " if issue.severity == QuestValidator.Severity.ERROR else "Warning: ") + issue.message)
		_problems.set_item_metadata(index, issue.node_id)
		_problems.set_item_custom_fg_color(index, Color("e5534b") if issue.severity == QuestValidator.Severity.ERROR else Color("e5b34b"))


func _on_problem_selected(index: int) -> void:
	var node_id: String = _problems.get_item_metadata(index) if _problems.get_item_metadata(index) != null else ""
	if node_id.is_empty():
		EditorInterface.edit_resource(_quest)
		return
	_select_node_ids([node_id])


func _rebuild_relations() -> void:
	var counts := QuestRelationsView.build(_graph, _get_source_quests(), _quest)
	_problems.clear()
	_problems.add_item("Showing %d quests and %d links. Toggle Relations to return." % [counts.x, counts.y])
	_problems.set_item_disabled(0, true)




func _apply_runtime() -> void:
	if not is_node_ready():
		return
	var running := not _runtime.is_empty() and not _show_relations
	_runtime_row.visible = running
	_runtime_label.text = ""
	var states := {}
	if running:
		for node: Dictionary in _runtime.get("nodes", []):
			var state: Variant = node.get("state", 0)
			states[node.get("id", "")] = state if state is int else QuestNode.State.keys().find(str(state).to_upper())
		var quest_state: Variant = _runtime.get("state", 0)
		var quest_state_name: String = Quest.State.keys()[quest_state] if quest_state is int else str(quest_state)
		_runtime_label.text = "Running: %s" % quest_state_name.capitalize()
		if not _runtime_state.get_popup().visible:
			_runtime_state.select(clampi(Quest.State.keys().find(quest_state_name.to_upper()), 0, Quest.State.size() - 1))
	for child in _graph.get_children():
		if child is QuestGraphNode:
			child.set_runtime_state(states.get(child.quest_node.id, -1) if running else -1)


func _on_connection_request(from_name: StringName, _from_port: int, to_name: StringName, _to_port: int) -> void:
	if _show_relations:
		return
	var from_node := _node_of(from_name)
	var to_node := _node_of(to_name)
	if from_node != null and to_node != null:
		_commit("Connect Quest Nodes", func() -> void: QuestGraphOps.connect_nodes(_quest, from_node.id, to_node.id))


func _on_disconnection_request(from_name: StringName, _from_port: int, to_name: StringName, _to_port: int) -> void:
	if _show_relations:
		return
	var from_node := _node_of(from_name)
	var to_node := _node_of(to_name)
	if from_node != null and to_node != null:
		_commit("Disconnect Quest Nodes", func() -> void: QuestGraphOps.disconnect_nodes(_quest, from_node.id, to_node.id))


func _on_delete_nodes_request(names: Array[StringName]) -> void:
	if _show_relations:
		return
	var ids: Array = []
	for graph_name in names:
		var node := _node_of(graph_name)
		if node != null:
			ids.append(node.id)
	if ids.is_empty():
		return
	_selected_ids.clear()
	_commit("Delete Quest Nodes", func() -> void: QuestGraphOps.delete_nodes(_quest, ids))


func _on_end_node_move() -> void:
	if _quest == null or _show_relations:
		return
	var moved := false
	for child in _graph.get_children():
		if child is QuestGraphNode and child.quest_node.editor_position != child.position_offset:
			moved = true
	if not moved:
		return
	var positions := {}
	for child in _graph.get_children():
		if child is QuestGraphNode:
			positions[child.quest_node] = child.position_offset
	_commit("Move Quest Nodes", func() -> void:
		for node: QuestNode in positions:
			node.editor_position = positions[node])


func _on_node_selected(graph_node: Node) -> void:
	if _rebuilding:
		return
	if _show_relations:
		var quests := _get_source_quests()
		var index := int(String(graph_node.name).substr(1))
		var visible_quests := quests.filter(func(q: Quest) -> bool: return q != null)
		if index < visible_quests.size():
			_relations_button.button_pressed = false
			_set_quest(visible_quests[index])
			EditorInterface.edit_resource(visible_quests[index])
		return
	var node := _node_of(graph_node.name)
	if node == null:
		return
	if not _selected_ids.has(node.id):
		_selected_ids.append(node.id)
	if _selected_ids.size() == 1:
		EditorInterface.edit_resource(node)
	_rebuild_outline()


func _on_node_deselected(graph_node: Node) -> void:
	if _rebuilding:
		return
	var node := _node_of(graph_node.name)
	if node != null:
		_selected_ids.erase(node.id)
	_after_deselect.call_deferred()


func _after_deselect() -> void:
	if _quest != null and _selected_ids.is_empty() and not _show_relations:
		EditorInterface.edit_resource(_quest)
	_rebuild_outline()


func _selected_graph_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for child in _graph.get_children():
		if child is QuestGraphNode and child.selected:
			names.append(child.name)
	return names


func _select_node_ids(ids: Array) -> void:
	_selected_ids.assign(ids)
	for child in _graph.get_children():
		if child is QuestGraphNode:
			child.selected = ids.has(child.quest_node.id)
	if ids.size() == 1:
		var node := QuestGraphOps.find_node(_quest, ids[0])
		if node != null:
			EditorInterface.edit_resource(node)
	_rebuild_outline()


func _node_of(graph_name: StringName) -> QuestNode:
	var graph_node := _graph.get_node_or_null(NodePath(graph_name))
	return graph_node.quest_node if graph_node is QuestGraphNode else null


## Runs `mutate` on the quest and records it for undo, then repaints.
func _commit(action_name: String, mutate: Callable) -> void:
	if _quest == null:
		return
	var before := QuestGraphOps.snapshot(_quest)
	mutate.call()
	var after := QuestGraphOps.snapshot(_quest)
	if undo_redo != null:
		undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, _quest)
		undo_redo.add_do_method(self, "_restore", _quest, after)
		undo_redo.add_undo_method(self, "_restore", _quest, before)
		undo_redo.commit_action(false)
	_quest.emit_changed()
	_dirty = true
	_queue_refresh()


func _restore(quest: Quest, snapshot: Dictionary) -> void:
	QuestGraphOps.restore(quest, snapshot)
	quest.emit_changed()
	_dirty = true
	_queue_refresh()



# --------------------------------------------------------------- context menu

func _on_popup_request(at_position: Vector2) -> void:
	if _quest == null or _show_relations:
		return
	_context_position = (_graph.scroll_offset + at_position) / _graph.zoom
	_context_node_id = ""
	for child in _graph.get_children():
		if child is QuestGraphNode and Rect2(child.position, child.size).has_point(at_position):
			_context_node_id = child.quest_node.id
	_context_menu.reset()
	_add_new_node_items()
	if not _context_node_id.is_empty():
		_add_node_items(_target_ids())
	_context_menu.add_action("Paste", _paste, not _clipboard.is_empty())
	_context_menu.add_separator()
	var wizard_menu := _context_menu.add_submenu("Wizard")
	_context_menu.add_action("Counter Requirement...", func() -> void: _open_wizard(QuestWizards.COUNTER), true, wizard_menu)
	_context_menu.add_action("Message Requirement...", func() -> void: _open_wizard(QuestWizards.MESSAGE), true, wizard_menu)
	_context_menu.add_action("Return to Quest Giver...", func() -> void: _open_wizard(QuestWizards.RETURN), true, wizard_menu)
	_context_menu.add_action("Arrange Nodes", func() -> void: _arrange(false))
	if not _runtime.is_empty() and not _context_node_id.is_empty() and debugger != null:
		_add_runtime_items()
	_context_menu.popup_at_mouse()


func _add_new_node_items() -> void:
	var new_menu := _context_menu.add_submenu("New Node")
	_context_menu.add_action("Passthrough", func() -> void: _add_node(QuestNode.Type.PASSTHROUGH), true, new_menu)
	_context_menu.add_action("Condition", func() -> void: _add_node(QuestNode.Type.CONDITION), true, new_menu)
	_context_menu.add_action("Success", func() -> void: _add_node(QuestNode.Type.SUCCESS), true, new_menu)
	_context_menu.add_action("Failure", func() -> void: _add_node(QuestNode.Type.FAILURE), true, new_menu)


## Items for the clicked node: change type, clear, duplicate, copy and delete.
func _add_node_items(targets: Array) -> void:
	var is_start := QuestGraphOps.node_index(_quest, _context_node_id) == 0
	var end_node := QuestGraphOps.find_node(_quest, _context_node_id).node_type
	if end_node == QuestNode.Type.SUCCESS or end_node == QuestNode.Type.FAILURE:
		_context_menu.set_item_disabled(_context_menu.item_count - 1, true)
	if not is_start:
		var type_menu := _context_menu.add_submenu("Change Type")
		for type: QuestNode.Type in [QuestNode.Type.PASSTHROUGH, QuestNode.Type.CONDITION, QuestNode.Type.SUCCESS, QuestNode.Type.FAILURE]:
			_context_menu.add_action(QuestNode.Type.keys()[type].capitalize(), func() -> void:
				_commit("Change Node Type", func() -> void:
					for id in targets:
						QuestGraphOps.change_type(_quest, id, type)), true, type_menu)
	_context_menu.add_action("Clear Connections", func() -> void:
		_commit("Clear Node Connections", func() -> void:
			for id in targets:
				QuestGraphOps.clear_connections(_quest, id)))
	_context_menu.add_action("Duplicate", _duplicate_selected, not is_start)
	_context_menu.add_action("Copy", func() -> void: _copy_ids(targets), not is_start)
	_context_menu.add_action("Delete" if targets.size() <= 1 else "Delete Nodes", func() -> void:
		_selected_ids.clear()
		_commit("Delete Quest Nodes", func() -> void: QuestGraphOps.delete_nodes(_quest, targets)), not is_start)


func _add_runtime_items() -> void:
	_context_menu.add_separator()
	var state_menu := _context_menu.add_submenu("Set State")
	for state in QuestNode.State.size():
		_context_menu.add_action(QuestNode.State.keys()[state].capitalize(), func() -> void:
			debugger.send_command("quests:set_node_state", [_runtime_list_id, _quest.id, _context_node_id, state]), true, state_menu)


## The nodes a context action applies to: the selection when the clicked node
## is part of it, otherwise the clicked node.
func _target_ids() -> Array:
	if _context_node_id.is_empty() or _selected_ids.has(_context_node_id):
		return _selected_ids.duplicate()
	return [_context_node_id]


func _add_node(type: QuestNode.Type) -> void:
	var parent_id := _context_node_id
	var position := _context_position
	if not parent_id.is_empty():
		var parent := QuestGraphOps.find_node(_quest, parent_id)
		position = parent.editor_position + Vector2(QuestGraphOps.NODE_SIZE.x + 40.0, 0.0)
	var created: Array[QuestNode] = []
	_commit("Add Quest Node", func() -> void: created.append(QuestGraphOps.create_node(_quest, type, position, parent_id)))
	if not created.is_empty():
		_select_node_ids([created[0].id])


func _copy_ids(ids: Array) -> void:
	_clipboard = QuestGraphOps.copy_nodes(_quest, ids)


func _copy_selected() -> void:
	_copy_ids(_selected_ids)


func _paste() -> void:
	if _clipboard.is_empty() or _quest == null:
		return
	var anchor := Vector2.INF
	for node: QuestNode in _clipboard:
		anchor = anchor.min(node.editor_position)
	var target := _context_position if _context_position != Vector2.ZERO else anchor + Vector2(40, 40)
	var pasted: Array[QuestNode] = []
	_commit("Paste Quest Nodes", func() -> void: pasted.assign(QuestGraphOps.paste_nodes(_quest, _clipboard, target - anchor)))
	_context_position = Vector2.ZERO
	_select_node_ids(pasted.map(func(n: QuestNode) -> String: return n.id))


func _duplicate_selected() -> void:
	if _selected_ids.is_empty():
		return
	var created: Array[QuestNode] = []
	_commit("Duplicate Quest Nodes", func() -> void: created.assign(QuestGraphOps.duplicate_nodes(_quest, _selected_ids)))
	_select_node_ids(created.map(func(n: QuestNode) -> String: return n.id))


func _arrange(_ignored: bool) -> void:
	if _quest == null:
		return
	var ids := _selected_ids.duplicate()
	_commit("Arrange Quest Nodes", func() -> void: QuestGraphOps.arrange(_quest, ids))



# ------------------------------------------------------------ toolbar actions

func _on_toolbar_menu(id: int) -> void:
	match id:
		Menu.NEW_QUEST:
			_files.new_quest()
		Menu.ADD_EXISTING:
			_files.add_existing()
		Menu.ADD_FROM_SCENE:
			_add_quests_from_scene()
		Menu.DUPLICATE_QUEST:
			_files.duplicate_quest()
		Menu.REMOVE_QUEST:
			if _quest != null:
				_remove_dialog.dialog_text = "Remove '%s' from this list, or delete its file from the project?" % (_quest.title if not _quest.title.is_empty() else _quest.id)
				_remove_dialog.popup_centered()
		Menu.SORT_ID, Menu.SORT_TITLE:
			var sorted := _get_source_quests().duplicate()
			QuestGraphOps.sort_quests(sorted, "id" if id == Menu.SORT_ID else "title")
			_set_source_quests(sorted, "Sort Quests")
		Menu.NODE_PASSTHROUGH, Menu.NODE_CONDITION, Menu.NODE_SUCCESS, Menu.NODE_FAILURE:
			_context_node_id = _selected_ids[0] if _selected_ids.size() == 1 else ""
			_context_position = (_graph.scroll_offset + _graph.size / 2.0) / _graph.zoom
			_add_node({
				Menu.NODE_PASSTHROUGH: QuestNode.Type.PASSTHROUGH, Menu.NODE_CONDITION: QuestNode.Type.CONDITION,
				Menu.NODE_SUCCESS: QuestNode.Type.SUCCESS, Menu.NODE_FAILURE: QuestNode.Type.FAILURE}[id])
		Menu.WIZARD_COUNTER, Menu.WIZARD_MESSAGE, Menu.WIZARD_RETURN:
			_context_node_id = _selected_ids[0] if _selected_ids.size() == 1 else ""
			_open_wizard({
				Menu.WIZARD_COUNTER: QuestWizards.COUNTER, Menu.WIZARD_MESSAGE: QuestWizards.MESSAGE,
				Menu.WIZARD_RETURN: QuestWizards.RETURN}[id])
		Menu.EXPORT_JSON:
			_files.export_json()
		Menu.IMPORT_JSON:
			_files.import_json()


## Adds every quest asset assigned to a QuestList in the open scene.
func _add_quests_from_scene() -> void:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return
	var quests := _get_source_quests().duplicate()
	var added := 0
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is QuestList:
			for quest in node.quests:
				if quest != null and not quests.has(quest) and _source != node:
					quests.append(quest)
					added += 1
	if added > 0:
		var typed: Array[Quest] = []
		typed.assign(quests)
		_set_source_quests(typed, "Add Quests From Scene")


func _add_to_source(quest: Quest) -> void:
	var quests := _get_source_quests().duplicate()
	if not quests.has(quest):
		quests.append(quest)
	var typed: Array[Quest] = []
	typed.assign(quests)
	_set_source_quests(typed, "Add Quest")
	_set_quest(quest)
	EditorInterface.edit_resource(quest)


func _remove_current_quest(delete_file: bool) -> void:
	if _quest == null:
		return
	var removed := _quest
	var quests := _get_source_quests().duplicate()
	var index := quests.find(removed)
	quests.erase(removed)
	var typed: Array[Quest] = []
	typed.assign(quests)
	_set_source_quests(typed, "Remove Quest")
	if delete_file and not removed.resource_path.is_empty() and not "::" in removed.resource_path:
		OS.move_to_trash(ProjectSettings.globalize_path(removed.resource_path))
		EditorInterface.get_resource_filesystem().scan()
	_set_quest(typed[clampi(index, 0, typed.size() - 1)] if not typed.is_empty() else null)


func _open_wizard(wizard_id: String) -> void:
	if _quest == null:
		return
	var wizard: Dictionary = QuestWizards.get_wizards()[wizard_id]
	var clicked := _context_node_id
	_form.open(wizard.title + " Wizard", wizard.help, wizard.fields, func(values: Dictionary) -> void:
		var created: Array[QuestNode] = []
		_commit("Add " + wizard.title + " Node", func() -> void: created.append(QuestWizards.apply_wizard(wizard_id, _quest, clicked, values)))
		if not created.is_empty() and created[0] != null:
			_select_node_ids([created[0].id]))



# ------------------------------------------------------------ outline, reference

func _rebuild_outline() -> void:
	_outline.rebuild(_quest, _selected_ids)


func _show_reference() -> void:
	if _reference_dialog == null:
		_reference_dialog = QuestReferenceDialog.new()
		add_child(_reference_dialog)
	_reference_dialog.show_reference(_quest)


# -------------------------------------------------------------------- saving

func _save_quest(force: bool) -> void:
	if _quest == null:
		return
	var path := _quest.resource_path
	if path.is_empty():
		if force:
			push_warning("Quests: This quest is not saved to a file. Use New > New Quest, or save it from the inspector.")
		return
	if "::" in path:
		path = path.get_slice("::", 0)
		var owner_resource := load(path)
		if owner_resource is Resource:
			ResourceSaver.save(owner_resource, path)
		_dirty = false
		return
	var error := ResourceSaver.save(_quest, path)
	if error != OK:
		push_error("Quests: Could not save %s (error %d)." % [path, error])
	else:
		_dirty = false
