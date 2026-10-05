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

const SETTING_AUTO_SAVE := "quests/editor/auto_save"
const SETTING_DIRECTORY := "quests/editor/new_quest_directory"

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
var _menu_actions: Dictionary = {}
var _outline_actions: Dictionary = {}

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
var _outline := Tree.new()
var _context_menu := PopupMenu.new()
var _outline_menu := PopupMenu.new()
var _form := QuestFormDialog.new()
var _file_dialog := EditorFileDialog.new()
var _file_mode := ""
var _confirm := ConfirmationDialog.new()
var _remove_dialog := ConfirmationDialog.new()
var _runtime_row := HBoxContainer.new()
var _runtime_state := OptionButton.new()
var _reference_dialog: AcceptDialog
var _save_timer := Timer.new()
var _pending_template := ""
var _pending_template_params: Dictionary = {}
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
	_toolbar.add_theme_constant_override("separation", 6)
	add_child(_toolbar)
	_source_label.text = "No quest open"
	_source_label.add_theme_font_size_override("font_size", 14)
	_toolbar.add_child(_source_label)
	_toolbar.add_child(VSeparator.new())
	_setup_menu_button(_new_button, "New", "Add")
	var new_popup := _new_button.get_popup()
	new_popup.add_item("New Quest...", Menu.NEW_QUEST)
	var templates := PopupMenu.new()
	templates.name = "templates"
	new_popup.add_child(templates)
	var template_ids := QuestWizards.get_templates().keys()
	for index in template_ids.size():
		templates.add_item(QuestWizards.get_templates()[template_ids[index]].title, Menu.TEMPLATE_BASE + index)
	templates.id_pressed.connect(func(id: int) -> void: _on_template_chosen(String(template_ids[id - Menu.TEMPLATE_BASE])))
	new_popup.add_submenu_node_item("New From Template", templates, Menu.NEW_FROM_TEMPLATE)
	new_popup.add_separator()
	new_popup.add_item("Add Existing Quest...", Menu.ADD_EXISTING)
	new_popup.add_item("Add Quests From Open Scene", Menu.ADD_FROM_SCENE)
	new_popup.id_pressed.connect(_on_toolbar_menu)
	_setup_menu_button(_node_button, "Add Node", "New")
	var node_popup := _node_button.get_popup()
	node_popup.add_item("Passthrough", Menu.NODE_PASSTHROUGH)
	node_popup.add_item("Condition", Menu.NODE_CONDITION)
	node_popup.add_item("Success", Menu.NODE_SUCCESS)
	node_popup.add_item("Failure", Menu.NODE_FAILURE)
	node_popup.id_pressed.connect(_on_toolbar_menu)
	_setup_menu_button(_wizard_button, "Wizards", "Tools")
	var wizard_popup := _wizard_button.get_popup()
	wizard_popup.add_item("Counter Requirement...", Menu.WIZARD_COUNTER)
	wizard_popup.add_item("Message Requirement...", Menu.WIZARD_MESSAGE)
	wizard_popup.add_item("Return to Quest Giver...", Menu.WIZARD_RETURN)
	wizard_popup.add_separator()
	wizard_popup.add_item("Export Quest to JSON...", Menu.EXPORT_JSON)
	wizard_popup.add_item("Import Quest from JSON...", Menu.IMPORT_JSON)
	wizard_popup.id_pressed.connect(_on_toolbar_menu)
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

	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_split)

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
	_split.add_child(left)

	var center_split := HSplitContainer.new()
	center_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.add_child(center_split)
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_split.add_child(center)

	var graph_holder := Control.new()
	graph_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(graph_holder)
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
	graph_holder.add_child(_graph)
	_empty_label.text = "Select a Quest or QuestDatabase resource, or use New > New Quest."
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_empty_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	graph_holder.add_child(_empty_label)

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
	center.add_child(_runtime_row)

	_problems.custom_minimum_size.y = 90
	_problems.item_selected.connect(_on_problem_selected)
	center.add_child(_problems)

	_outline.custom_minimum_size.x = 260
	_outline.hide_root = true
	_outline.item_selected.connect(_on_outline_selected)
	_outline.item_mouse_selected.connect(_on_outline_mouse_selected)
	center_split.add_child(_outline)


func _setup_menu_button(button: MenuButton, text: String, icon_name: String) -> void:
	button.text = text
	button.flat = false
	button.icon = EditorInterface.get_editor_theme().get_icon(icon_name, "EditorIcons")
	_toolbar.add_child(button)


func _build_dialogs() -> void:
	for dialog: Node in [_form, _confirm, _remove_dialog, _file_dialog, _context_menu, _outline_menu, _save_timer]:
		add_child(dialog)
	_context_menu.id_pressed.connect(_on_context_menu_id)
	_outline_menu.id_pressed.connect(_on_outline_menu_id)
	_confirm.confirmed.connect(func() -> void:
		if _menu_actions.has("confirm"):
			_menu_actions["confirm"].call())
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
	_file_dialog.file_selected.connect(_on_file_selected)
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
	var quests := _get_source_quests()
	var positions := {}
	var index := 0
	for quest in quests:
		if quest == null:
			continue
		var graph_node := GraphNode.new()
		graph_node.name = "q%d" % index
		graph_node.title = quest.title if not quest.title.is_empty() else quest.id
		graph_node.position_offset = Vector2(40 + (index % 4) * 280, 40 + (index / 4) * 150)
		graph_node.resizable = false
		var label := Label.new()
		label.text = quest.id
		graph_node.add_child(label)
		graph_node.set_slot(0, true, 0, Color("f2c14e"), true, 0, Color("f2c14e"))
		graph_node.selected = quest == _quest
		_graph.add_child(graph_node)
		positions[quest.id] = graph_node.name
		index += 1
	var edges := {}
	for quest in quests:
		if quest == null:
			continue
		for required in quest.requires_quests:
			_add_edge(edges, positions, required, quest.id)
		for entry in QuestValidator.collect_subassets(quest):
			var asset: Resource = entry.asset
			if QuestValidator.refers_to_other_quest(asset, quest):
				_add_edge(edges, positions, quest.id, asset.get(QuestValidator._quest_property(asset)))
	_problems.clear()
	_problems.add_item("Showing %d quests and %d links. Toggle Relations to return." % [index, edges.size()])
	_problems.set_item_disabled(0, true)


func _add_edge(edges: Dictionary, positions: Dictionary, from_id: String, to_id: String) -> void:
	var key := "%s>%s" % [from_id, to_id]
	if from_id != to_id and positions.has(from_id) and positions.has(to_id) and not edges.has(key):
		edges[key] = true
		_graph.connect_node(positions[from_id], 0, positions[to_id], 0)


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
	var targets := _target_ids()
	_context_menu.clear()
	_menu_actions.clear()
	for child in _context_menu.get_children():
		if child is PopupMenu:
			_context_menu.remove_child(child)
			child.queue_free()
	var is_start := not _context_node_id.is_empty() and QuestGraphOps.node_index(_quest, _context_node_id) == 0
	var new_menu := _submenu("New Node")
	_add_item(new_menu, "Passthrough", func() -> void: _add_node(QuestNode.Type.PASSTHROUGH))
	_add_item(new_menu, "Condition", func() -> void: _add_node(QuestNode.Type.CONDITION))
	_add_item(new_menu, "Success", func() -> void: _add_node(QuestNode.Type.SUCCESS))
	_add_item(new_menu, "Failure", func() -> void: _add_node(QuestNode.Type.FAILURE))
	if not _context_node_id.is_empty():
		var end_node := QuestGraphOps.find_node(_quest, _context_node_id).node_type
		if end_node == QuestNode.Type.SUCCESS or end_node == QuestNode.Type.FAILURE:
			_context_menu.set_item_disabled(_context_menu.get_item_index(_context_menu.item_count - 1), true)
		if not is_start:
			var type_menu := _submenu("Change Type")
			for type: QuestNode.Type in [QuestNode.Type.PASSTHROUGH, QuestNode.Type.CONDITION, QuestNode.Type.SUCCESS, QuestNode.Type.FAILURE]:
				_add_item(type_menu, QuestNode.Type.keys()[type].capitalize(), func() -> void:
					_commit("Change Node Type", func() -> void:
						for id in targets:
							QuestGraphOps.change_type(_quest, id, type)))
		_add_item(_context_menu, "Clear Connections", func() -> void:
			_commit("Clear Node Connections", func() -> void:
				for id in targets:
					QuestGraphOps.clear_connections(_quest, id)))
		_add_item(_context_menu, "Duplicate", _duplicate_selected, not is_start)
		_add_item(_context_menu, "Copy", func() -> void: _copy_ids(targets), not is_start)
		_add_item(_context_menu, "Delete" if targets.size() <= 1 else "Delete Nodes", func() -> void:
			_selected_ids.clear()
			_commit("Delete Quest Nodes", func() -> void: QuestGraphOps.delete_nodes(_quest, targets)), not is_start)
	_add_item(_context_menu, "Paste", _paste, not _clipboard.is_empty())
	_context_menu.add_separator()
	var wizard_menu := _submenu("Wizard")
	_add_item(wizard_menu, "Counter Requirement...", func() -> void: _open_wizard(QuestWizards.COUNTER))
	_add_item(wizard_menu, "Message Requirement...", func() -> void: _open_wizard(QuestWizards.MESSAGE))
	_add_item(wizard_menu, "Return to Quest Giver...", func() -> void: _open_wizard(QuestWizards.RETURN))
	_add_item(_context_menu, "Arrange Nodes", func() -> void: _arrange(false))
	if not _runtime.is_empty() and not _context_node_id.is_empty() and debugger != null:
		_context_menu.add_separator()
		var state_menu := _submenu("Set State")
		for state in QuestNode.State.size():
			_add_item(state_menu, QuestNode.State.keys()[state].capitalize(), func() -> void:
				debugger.send_command("quests:set_node_state", [_runtime_list_id, _quest.id, _context_node_id, state]))
	_context_menu.position = Vector2i(DisplayServer.mouse_get_position())
	_context_menu.popup()


func _submenu(title: String) -> PopupMenu:
	var menu := PopupMenu.new()
	menu.name = title.replace(" ", "")
	menu.id_pressed.connect(_on_context_menu_id)
	_context_menu.add_child(menu)
	_context_menu.add_submenu_node_item(title, menu)
	return menu


func _add_item(menu: PopupMenu, text: String, action: Callable, enabled := true) -> void:
	var id := _menu_actions.size() + 1
	menu.add_item(text, id)
	menu.set_item_disabled(menu.item_count - 1, not enabled)
	_menu_actions[id] = action


func _on_context_menu_id(id: int) -> void:
	if _menu_actions.has(id):
		_menu_actions[id].call()


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
			_set_file_filter("*.tres", "Quest resource")
			_file_mode = "new"
			_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
			_file_dialog.title = "Create Quest"
			_file_dialog.current_dir = ProjectSettings.get_setting(SETTING_DIRECTORY, "res://")
			_file_dialog.current_file = "new_quest.tres"
			_file_dialog.popup_file_dialog()
		Menu.ADD_EXISTING:
			_set_file_filter("*.tres", "Quest resource")
			_file_mode = "existing"
			_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
			_file_dialog.title = "Add Existing Quest"
			_file_dialog.popup_file_dialog()
		Menu.ADD_FROM_SCENE:
			_add_quests_from_scene()
		Menu.DUPLICATE_QUEST:
			_duplicate_quest()
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
		Menu.WIZARD_COUNTER:
			_context_node_id = _selected_ids[0] if _selected_ids.size() == 1 else ""
			_open_wizard(QuestWizards.COUNTER)
		Menu.WIZARD_MESSAGE:
			_context_node_id = _selected_ids[0] if _selected_ids.size() == 1 else ""
			_open_wizard(QuestWizards.MESSAGE)
		Menu.WIZARD_RETURN:
			_context_node_id = _selected_ids[0] if _selected_ids.size() == 1 else ""
			_open_wizard(QuestWizards.RETURN)
		Menu.EXPORT_JSON:
			if _quest != null:
				_file_mode = "export"
				_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
				_file_dialog.title = "Export Quest to JSON"
				_file_dialog.clear_filters()
				_file_dialog.add_filter("*.json", "JSON")
				_file_dialog.current_file = _quest.id + ".json"
				_file_dialog.popup_file_dialog()
		Menu.IMPORT_JSON:
			_file_mode = "import"
			_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
			_file_dialog.title = "Import Quest from JSON"
			_file_dialog.clear_filters()
			_file_dialog.add_filter("*.json", "JSON")
			_file_dialog.popup_file_dialog()


func _on_file_selected(path: String) -> void:
	if _file_mode == "new":
		var base := path.get_file().get_basename()
		var quest := QuestGraphOps.new_quest(base, base.capitalize())
		_save_new_quest(quest, path)
	elif _file_mode == "existing":
		var loaded := load(path)
		if loaded is Quest:
			_add_to_source(loaded)
		elif loaded is QuestDatabase:
			edit_object(loaded)
		else:
			push_warning("Quests: %s is not a Quest or QuestDatabase." % path)
	elif _file_mode == "export":
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(QuestSerializer.quest_to_dict(_quest), "\t"))
		else:
			push_error("Quests: Could not write %s." % path)
	elif _file_mode == "import":
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			var imported := QuestSerializer.dict_to_quest(parsed)
			if imported != null:
				imported.id = _unique_quest_id(imported.id)
				_file_mode = "new"
				_save_new_quest(imported, ProjectSettings.get_setting(SETTING_DIRECTORY, "res://").path_join(imported.id + ".tres"))
		else:
			push_warning("Quests: %s is not a quest JSON file." % path)
	elif _file_mode == "template":
		var quest := QuestWizards.create_from_template(_pending_template, _pending_template_params)
		if quest != null:
			_save_new_quest(quest, path)



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


func _set_file_filter(filter: String, description: String) -> void:
	_file_dialog.clear_filters()
	_file_dialog.add_filter(filter, description)


func _save_new_quest(quest: Quest, path: String) -> void:
	ProjectSettings.set_setting(SETTING_DIRECTORY, path.get_base_dir())
	var error := ResourceSaver.save(quest, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		push_error("Quests: Could not save %s (error %d)." % [path, error])
		return
	EditorInterface.get_resource_filesystem().update_file(path)
	context.mark_dirty()
	_add_to_source(quest)


func _add_to_source(quest: Quest) -> void:
	var quests := _get_source_quests().duplicate()
	if not quests.has(quest):
		quests.append(quest)
	var typed: Array[Quest] = []
	typed.assign(quests)
	_set_source_quests(typed, "Add Quest")
	_set_quest(quest)
	EditorInterface.edit_resource(quest)


func _on_template_chosen(template_id: String) -> void:
	var template: Dictionary = QuestWizards.get_templates()[template_id]
	var fields: Array = template.fields
	_form.open("New Quest: " + template.title, template.help, fields, func(values: Dictionary) -> void:
		_pending_template = template_id
		_pending_template_params = values
		var quest_id: String = values.get("id", "")
		if quest_id.is_empty():
			quest_id = String(values.get("title", template.title)).to_snake_case()
		_set_file_filter("*.tres", "Quest resource")
		_file_mode = "template"
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		_file_dialog.title = "Save New Quest"
		_file_dialog.current_dir = ProjectSettings.get_setting(SETTING_DIRECTORY, "res://")
		_file_dialog.current_file = quest_id + ".tres"
		_file_dialog.popup_file_dialog(), "Create...", QuestWizards.defaults(fields))


func _duplicate_quest() -> void:
	if _quest == null:
		return
	var copy: Quest = _quest.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	copy.id = _unique_quest_id(_quest.id + "_copy")
	copy.title = _quest.title + " (copy)"
	var base_dir := _quest.resource_path.get_base_dir() if not _quest.resource_path.is_empty() and not "::" in _quest.resource_path else "res://"
	var path := base_dir.path_join(copy.id + ".tres")
	copy.resource_path = ""
	_save_new_quest(copy, path)


func _unique_quest_id(base: String) -> String:
	var ids := context.get_quest_ids()
	var candidate := base
	var index := 2
	while ids.has(candidate):
		candidate = "%s_%d" % [base, index]
		index += 1
	return candidate


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


func _show_reference() -> void:
	if _reference_dialog == null:
		_reference_dialog = AcceptDialog.new()
		_reference_dialog.title = "Quest Reference"
		_reference_dialog.min_size = Vector2(520, 480)
		add_child(_reference_dialog)
	for child in _reference_dialog.get_children():
		if child is TabContainer:
			_reference_dialog.remove_child(child)
			child.queue_free()
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(500, 400)
	tabs.add_child(_reference_page("Tags", _tag_entries()))
	tabs.add_child(_reference_page("Messages", _message_entries()))
	_reference_dialog.add_child(tabs)
	_reference_dialog.popup_centered()


func _reference_page(page_name: String, entries: Array) -> Control:
	var scroll := ScrollContainer.new()
	scroll.name = page_name
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	for entry: Array in entries:
		var button := Button.new()
		button.text = entry[0]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.tooltip_text = entry[1] + "\nClick to copy."
		button.pressed.connect(func() -> void: DisplayServer.clipboard_set(entry[0]))
		box.add_child(button)
	return scroll


func _tag_entries() -> Array:
	var entries: Array = []
	var tags_script: GDScript = QuestTags
	var constants := tags_script.get_script_constant_map()
	for constant_name: String in constants:
		if constants[constant_name] is String and String(constants[constant_name]).begins_with("{"):
			entries.append([constants[constant_name], constant_name.capitalize()])
	if _quest != null:
		for counter in _quest.counter_list:
			if counter != null:
				entries.append(["{#%s}" % counter.name, "Value of counter " + counter.name])
				entries.append(["{<#%s}" % counter.name, "Minimum of counter " + counter.name])
				entries.append(["{>#%s}" % counter.name, "Maximum of counter " + counter.name])
				entries.append(["{:%s}" % counter.name, "Counter " + counter.name + " as a time"])
	return entries


func _message_entries() -> Array:
	var entries: Array = []
	var messages_script: GDScript = QuestMessages
	var constants := messages_script.get_script_constant_map()
	for constant_name: String in constants:
		if constants[constant_name] is String:
			entries.append([constants[constant_name], constant_name.capitalize()])
	return entries


# ------------------------------------------------------------------- outline

func _rebuild_outline() -> void:
	if not is_node_ready():
		return
	_outline.clear()
	var root := _outline.create_item()
	if _quest == null:
		return
	var info := _section(root, "Quest Info", _quest)
	for line in [
		["ID", _quest.id], ["Title", _quest.title], ["Group", _quest.group],
		["Quest Giver", _quest.quest_giver_id],
		["Trackable", str(_quest.is_trackable)], ["Abandonable", str(_quest.is_abandonable)],
		["Max times", "unlimited" if _quest.infinitely_repeatable else str(_quest.max_times)],
		["Cooldown", "%d s" % int(_quest.cooldown_seconds)],
		["Time limit", "%d s" % int(_quest.time_limit) if _quest.time_limit > 0.0 else "none"],
		["Requires", ", ".join(_quest.requires_quests) if not _quest.requires_quests.is_empty() else "none"]]:
		_leaf(info, "%s: %s" % line, _quest)
	info.collapsed = true
	var counters := _section(root, "Counters (%d)" % _quest.counter_list.size(), _quest, "counters")
	for counter in _quest.counter_list:
		if counter != null:
			_leaf(counters, "%s  [%d..%d]" % [counter.name, counter.min_value, counter.max_value], counter, "counter")
	_condition_section(root, "Autostart Conditions", _quest.autostart_condition_set, "autostart")
	var offer := _condition_section(root, "Offer Conditions", _quest.offer_condition_set, "offer")
	var offer_content := _section(offer, "Offer Content (%d)" % _quest.offer_content_list.size(), _quest)
	for content in _quest.offer_content_list:
		if content != null:
			_leaf(offer_content, content.get_editor_name(), content)
	var unmet := _section(offer, "Unmet Content (%d)" % _quest.offer_conditions_unmet_content_list.size(), _quest)
	for content in _quest.offer_conditions_unmet_content_list:
		if content != null:
			_leaf(unmet, content.get_editor_name(), content)
	var states := _section(root, "States", _quest)
	for state in Quest.State.size():
		_state_item(states, Quest.State.keys()[state].capitalize(), _quest.state_info_list[state])
	if _selected_ids.size() == 1:
		var node := QuestGraphOps.find_node(_quest, _selected_ids[0])
		if node != null:
			var node_item := _section(root, "Node: %s" % (node.internal_name if not node.internal_name.is_empty() else node.id), node)
			if node.condition_set != null:
				var conditions := _section(node_item, "Conditions (%d)" % node.condition_set.condition_list.size(), node.condition_set)
				for condition in node.condition_set.condition_list:
					if condition != null:
						_leaf(conditions, condition.get_editor_name(), condition)
			for state in QuestNode.State.size():
				_state_item(node_item, QuestNode.State.keys()[state].capitalize(), node.state_info_list[state])


func _section(parent: TreeItem, text: String, resource: Variant, kind := "") -> TreeItem:
	var item := _outline.create_item(parent)
	item.set_text(0, text)
	item.set_metadata(0, {"resource": resource, "kind": kind})
	item.set_custom_bg_color(0, Color(1, 1, 1, 0.06))
	return item


func _leaf(parent: TreeItem, text: String, resource: Variant, kind := "") -> TreeItem:
	var item := _outline.create_item(parent)
	item.set_text(0, text)
	item.set_metadata(0, {"resource": resource, "kind": kind})
	return item


func _condition_section(parent: TreeItem, title: String, condition_set: QuestConditionSet, kind: String) -> TreeItem:
	var count := condition_set.condition_list.size() if condition_set != null else 0
	var item := _section(parent, "%s (%d)" % [title, count], condition_set if condition_set != null else _quest, kind)
	if condition_set != null:
		for condition in condition_set.condition_list:
			if condition != null:
				_leaf(item, condition.get_editor_name(), condition, "condition")
	return item


func _state_item(parent: TreeItem, title: String, info: QuestStateInfo) -> void:
	if info == null:
		return
	var item := _section(parent, title, info)
	for action in info.action_list:
		if action != null:
			_leaf(item, "Action: " + action.get_editor_name(), action)
	for category in [["Dialogue", info.dialogue_content], ["Journal", info.journal_content], ["HUD", info.hud_content]]:
		for content in category[1]:
			if content != null:
				_leaf(item, "%s: %s" % [category[0], content.get_editor_name()], content)
	item.collapsed = item.get_child_count() == 0 or title != "Active"


func _on_outline_selected() -> void:
	var item := _outline.get_selected()
	if item == null:
		return
	var data: Dictionary = item.get_metadata(0)
	var resource: Variant = data.resource
	if resource is Resource:
		EditorInterface.edit_resource(resource)
	elif resource == null and data.kind in ["autostart", "offer"]:
		_create_condition_set(data.kind)


func _create_condition_set(kind: String) -> void:
	if kind == "autostart":
		_quest.autostart_condition_set = QuestConditionSet.new()
	else:
		_quest.offer_condition_set = QuestConditionSet.new()
	_queue_refresh()


func _on_outline_mouse_selected(_position: Vector2, mouse_button: int) -> void:
	if mouse_button != MOUSE_BUTTON_RIGHT:
		return
	var item := _outline.get_selected()
	if item == null:
		return
	var data: Dictionary = item.get_metadata(0)
	_outline_menu.clear()
	_outline_actions.clear()
	match data.kind:
		"counters":
			_add_outline_item("Add Counter", func() -> void:
				_commit("Add Quest Counter", func() -> void:
					QuestGraphOps.add_counter(_quest, _unique_counter_name())))
		"counter":
			var counter: QuestCounter = data.resource
			_add_outline_item("Remove Counter", func() -> void:
				_commit("Remove Quest Counter", func() -> void: QuestGraphOps.remove_counter(_quest, counter.name)))
		"autostart", "offer":
			for script_class in _subclasses_of("QuestCondition"):
				_add_outline_item("Add " + script_class.trim_prefix("Quest").trim_suffix("Condition") + " Condition", func() -> void:
					_add_condition(data.kind, script_class))
		"condition":
			var condition: Resource = data.resource
			_add_outline_item("Remove Condition", func() -> void: _remove_condition(condition))
	if _outline_menu.item_count > 0:
		_outline_menu.position = Vector2i(DisplayServer.mouse_get_position())
		_outline_menu.popup()


func _add_outline_item(text: String, action: Callable) -> void:
	var id := _outline_actions.size() + 1
	_outline_menu.add_item(text, id)
	_outline_actions[id] = action


func _on_outline_menu_id(id: int) -> void:
	if _outline_actions.has(id):
		_outline_actions[id].call()


func _unique_counter_name() -> String:
	var index := 1
	while _counter_exists("counter%d" % index):
		index += 1
	return "counter%d" % index


func _counter_exists(counter_name: String) -> bool:
	for counter in _quest.counter_list:
		if counter != null and counter.name == counter_name:
			return true
	return false


func _add_condition(kind: String, script_class: String) -> void:
	var condition: QuestCondition = _instantiate(script_class)
	if condition == null:
		return
	var condition_set := _quest.autostart_condition_set if kind == "autostart" else _quest.offer_condition_set
	if condition_set == null:
		condition_set = QuestConditionSet.new()
		if kind == "autostart":
			_quest.autostart_condition_set = condition_set
		else:
			_quest.offer_condition_set = condition_set
	condition_set.condition_list.append(condition)
	_queue_refresh()
	EditorInterface.edit_resource(condition)


func _remove_condition(condition: Resource) -> void:
	for condition_set in [_quest.autostart_condition_set, _quest.offer_condition_set]:
		if condition_set != null and condition_set.condition_list.has(condition):
			condition_set.condition_list.erase(condition)
	for node in _quest.node_list:
		if node != null and node.condition_set != null:
			node.condition_set.condition_list.erase(condition)
	_queue_refresh()


## Names of the global classes that inherit `base`, sorted.
static func _subclasses_of(base: String) -> PackedStringArray:
	var parents := {}
	for entry in ProjectSettings.get_global_class_list():
		parents[entry["class"]] = entry["base"]
	var result := PackedStringArray()
	for class_name_text: String in parents:
		var current: String = parents[class_name_text]
		while not current.is_empty():
			if current == base:
				result.append(class_name_text)
				break
			current = parents.get(current, "")
	result.sort()
	return result


static func _instantiate(script_class: String) -> Resource:
	for entry in ProjectSettings.get_global_class_list():
		if entry["class"] == script_class:
			return load(entry["path"]).new()
	return null


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
