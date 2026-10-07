@tool
extends VBoxContainer
## The variables side panel: the variables of the open tree and the global variables,
## as rows with a name, a type and a remove button. Pick a row to edit its value in
## the inspector.

## A variable was picked and should be shown in the inspector.
signal inspect_requested(object: Object)

## Makes a change to the open tree undoable: [code]commit(action_name, mutate)[/code].
var commit: Callable
var undo_redo: EditorUndoRedoManager

var _tree: BehaviorTree
var _globals: BehaviorVariableSet
var _tabs := TabContainer.new()
var _tree_rows := VBoxContainer.new()
var _tree_add := Button.new()
var _globals_rows := VBoxContainer.new()
var _globals_add := Button.new()
var _globals_create := Button.new()
var _globals_note := Label.new()
var _rename_dialog := ConfirmationDialog.new()
var _pending_rename: Dictionary = {}
var _rebuild_queued := false


func _init() -> void:
	name = "Variables"
	custom_minimum_size.x = 260.0


func _ready() -> void:
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_tabs)
	_tabs.add_child(_make_tab("Variables", _tree_rows, _tree_add, "Add Variable", _on_add_tree_variable))
	var globals_tab := _make_tab("Globals", _globals_rows, _globals_add, "Add Global", _on_add_global)
	_tabs.add_child(globals_tab)
	_globals_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_globals_create.text = "Create global variables file"
	_globals_create.pressed.connect(_create_globals_file)
	globals_tab.add_child(_globals_note)
	globals_tab.move_child(_globals_note, 0)
	globals_tab.add_child(_globals_create)
	globals_tab.move_child(_globals_create, 1)
	add_child(_rename_dialog)
	_rename_dialog.title = "Rename Variable"
	_rename_dialog.ok_button_text = "Update Bindings"
	_rename_dialog.add_button("Keep Bindings", false, "keep")
	_rename_dialog.confirmed.connect(func() -> void: _finish_rename(true))
	_rename_dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"keep":
			_rename_dialog.hide()
			_finish_rename(false))
	_rename_dialog.canceled.connect(_queue_rebuild)
	refresh()


## Shows the variables of [param tree].
func set_tree(tree: BehaviorTree) -> void:
	_tree = tree
	refresh()


## Rebuilds the rows from the tree and the globals file.
func refresh() -> void:
	if not is_node_ready():
		return
	_globals = _load_globals()
	_rebuild()


func _queue_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _make_tab(tab_name: String, rows: VBoxContainer, add_button: Button, add_text: String, on_add: Callable) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = tab_name
	add_button.text = add_text
	add_button.icon = EditorInterface.get_editor_theme().get_icon("Add", "EditorIcons")
	add_button.pressed.connect(on_add)
	tab.add_child(add_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	tab.add_child(scroll)
	return tab


func _rebuild() -> void:
	_rebuild_queued = false
	_clear(_tree_rows)
	_clear(_globals_rows)
	_tree_add.disabled = _tree == null
	if _tree != null:
		for variable in _tree.variables:
			if variable:
				_tree_rows.add_child(_make_row(variable, commit, true))
		if _tree.variables.is_empty():
			_tree_rows.add_child(_hint("No variables. Add one, or bind a task property from the inspector."))
	var has_globals := _globals != null
	_globals_add.visible = has_globals
	_globals_create.visible = not has_globals
	var path: String = ProjectSettings.get_setting(Behaviors.SETTING_GLOBAL_VARIABLES, "")
	if has_globals:
		_globals_note.text = "Tasks reach these as global/<name>.\n" + path
		for variable in _globals.variables:
			if variable:
				_globals_rows.add_child(_make_row(variable, _commit_globals, false))
	elif path.is_empty():
		_globals_note.text = "No global variables file is set."
	else:
		_globals_note.text = "The global variables file %s could not be loaded." % path


func _clear(container: Control) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	return label


func _make_row(variable: BehaviorVariable, commit_fn: Callable, is_tree: bool) -> Control:
	var row := HBoxContainer.new()
	var name_edit := LineEdit.new()
	name_edit.text = String(variable.name)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.custom_minimum_size.x = 80.0
	name_edit.tooltip_text = variable.description
	name_edit.focus_entered.connect(func() -> void: inspect_requested.emit(variable))
	name_edit.text_submitted.connect(func(new_name: String) -> void:
		name_edit.release_focus())
	name_edit.focus_exited.connect(func() -> void:
		_rename(variable, name_edit.text, commit_fn, is_tree))
	row.add_child(name_edit)
	var type_button := OptionButton.new()
	for type in BehaviorGraphOps.VARIABLE_TYPES:
		type_button.add_item(type_string(type), type)
	if type_button.get_item_index(variable.type) < 0:
		type_button.add_item(type_string(variable.type), variable.type)
	type_button.select(type_button.get_item_index(variable.type))
	type_button.item_selected.connect(func(index: int) -> void:
		var new_type := type_button.get_item_id(index)
		commit_fn.call("Change Variable Type", func() -> void: variable.type = new_type)
		inspect_requested.emit(variable))
	row.add_child(type_button)
	var remove := Button.new()
	remove.flat = true
	remove.icon = EditorInterface.get_editor_theme().get_icon("Remove", "EditorIcons")
	remove.tooltip_text = "Remove variable"
	remove.pressed.connect(func() -> void:
		if is_tree:
			commit_fn.call("Remove Variable", func() -> void: _tree.variables.erase(variable))
		else:
			commit_fn.call("Remove Global Variable", func() -> void: _globals.variables.erase(variable)))
	row.add_child(remove)
	return row


func _rename(variable: BehaviorVariable, new_text: String, commit_fn: Callable, is_tree: bool) -> void:
	var new_name := new_text.strip_edges()
	var old_name := String(variable.name)
	if new_name == old_name:
		return
	if new_name.is_empty():
		_queue_rebuild()
		return
	if is_tree:
		var count := BehaviorGraphOps.count_bindings(_tree, old_name)
		if count > 0:
			_pending_rename = {"variable": variable, "old": old_name, "new": new_name}
			_rename_dialog.dialog_text = "%d task bindings use \"%s\".\nPoint them at \"%s\"?" % [count, old_name, new_name]
			_rename_dialog.popup_centered()
			return
	commit_fn.call("Rename Variable", func() -> void: variable.name = StringName(new_name))


func _finish_rename(update_bindings: bool) -> void:
	var variable: BehaviorVariable = _pending_rename.get("variable")
	if variable == null or _tree == null:
		return
	var old_name: String = _pending_rename["old"]
	var new_name: String = _pending_rename["new"]
	_pending_rename = {}
	commit.call("Rename Variable", func() -> void:
		variable.name = StringName(new_name)
		if update_bindings:
			BehaviorGraphOps.rename_bindings(_tree, old_name, new_name))


func _on_add_tree_variable() -> void:
	if _tree == null:
		return
	commit.call("Add Variable", func() -> void:
		var variable := BehaviorGraphOps.add_variable(_tree, "variable", TYPE_FLOAT)
		call_deferred("emit_signal", "inspect_requested", variable))


func _on_add_global() -> void:
	if _globals == null:
		return
	_commit_globals("Add Global Variable", func() -> void:
		var name := BehaviorGraphOps.unique_variable_name(_globals.variables, "global_variable")
		_globals.variables.append(BehaviorVariable.create(StringName(name), TYPE_FLOAT)))


func _load_globals() -> BehaviorVariableSet:
	var path: String = ProjectSettings.get_setting(Behaviors.SETTING_GLOBAL_VARIABLES, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as BehaviorVariableSet


func _create_globals_file() -> void:
	var path := "res://behavior_globals.tres"
	var variable_set := BehaviorVariableSet.new()
	variable_set.take_over_path(path)
	var error := ResourceSaver.save(variable_set, path)
	if error != OK:
		push_error("Behaviors: Could not create %s (error %d)." % [path, error])
		return
	ProjectSettings.set_setting(Behaviors.SETTING_GLOBAL_VARIABLES, path)
	ProjectSettings.save()
	Behaviors.reset_globals()
	refresh()


func _commit_globals(action_name: String, mutate: Callable) -> void:
	if _globals == null:
		return
	var before := BehaviorGraphOps.snapshot_variables(_globals.variables)
	mutate.call()
	var after := BehaviorGraphOps.snapshot_variables(_globals.variables)
	if before == after:
		return
	if undo_redo:
		undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, _globals)
		undo_redo.add_do_method(self, "_restore_globals", after)
		undo_redo.add_undo_method(self, "_restore_globals", before)
		undo_redo.commit_action(false)
	_save_globals()
	_queue_rebuild()


func _restore_globals(state: Dictionary) -> void:
	if _globals == null:
		return
	_globals.variables = BehaviorGraphOps.restore_variables(state)
	_save_globals()
	_queue_rebuild()


func _save_globals() -> void:
	if _globals == null or _globals.resource_path.is_empty():
		return
	ResourceSaver.save(_globals, _globals.resource_path)
	Behaviors.reset_globals()
