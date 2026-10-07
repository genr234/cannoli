@tool
extends EditorInspectorPlugin
## Inspector support for tasks and agents: a bindings section that ties task properties
## to variables, a replacement editor for bound properties, a button that links task
## references by clicking in the graph, and an "Open in Behaviors" button on agents.

const BoundProperty := preload("behavior_bound_property.gd")

const _BASE_CLASSES: PackedStringArray = [
	"BehaviorTask", "BehaviorParent", "BehaviorComposite", "BehaviorDecorator", "BehaviorAction", "BehaviorCondition",
]
const _NEW_VARIABLE := 1
const _VARIABLE_BASE := 100
const _GLOBAL_BASE := 10000

var undo_redo: EditorUndoRedoManager
## [code]get_tree_for(task) -> BehaviorTree[/code]: the tree being edited that holds the task.
var get_tree_for: Callable
## [code]open_in_editor(object)[/code]: shows the object in the Behaviors screen.
var open_in_editor: Callable
## [code]begin_link(task, property, class_name)[/code]: starts picking a task in the graph.
var begin_link: Callable
## [code]changed(task)[/code]: the graph should redraw the task.
var changed: Callable

var _skipped: Dictionary = {}


func _can_handle(object: Object) -> bool:
	return object is BehaviorTask or object is BehaviorAgent


func _parse_begin(object: Object) -> void:
	if object is BehaviorAgent:
		_add_agent_header(object)
	elif object is BehaviorTask:
		var tree: BehaviorTree = get_tree_for.call(object) if get_tree_for.is_valid() else null
		if tree != null:
			_add_bindings_section(object, tree)


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	var task := object as BehaviorTask
	if task == null:
		return false
	if task.bindings.has(StringName(name)):
		var variable_name := task.bindings[StringName(name)]
		add_property_editor(name, BoundProperty.new(variable_name, _set_binding.bind(task, name, "")))
		return true
	var link_class := _task_class_of(type, hint_type, hint_string)
	if not link_class.is_empty() and not BehaviorTaskCatalog.holds_inline_tasks(task) and begin_link.is_valid():
		var button := Button.new()
		button.text = "Pick in graph"
		button.tooltip_text = "Click a %s task in the graph to link it." % link_class.trim_prefix("Behavior").capitalize()
		button.pressed.connect(func() -> void: begin_link.call(task, StringName(name), link_class))
		add_custom_control(button)
	return false


func _add_agent_header(agent: BehaviorAgent) -> void:
	var row := HBoxContainer.new()
	var button := Button.new()
	button.text = "Open in Behaviors"
	button.pressed.connect(func() -> void:
		if open_in_editor.is_valid():
			open_in_editor.call(agent))
	row.add_child(button)
	var label := Label.new()
	if agent.tree:
		var count := agent.tree.validate().size()
		label.text = "%d issue%s" % [count, "" if count == 1 else "s"]
		label.add_theme_color_override("font_color", Color("f2c14e") if count > 0 else Color(0.6, 0.63, 0.7))
	else:
		label.text = "No tree"
		label.add_theme_color_override("font_color", Color(0.6, 0.63, 0.7))
	row.add_child(label)
	add_custom_control(row)


func _add_bindings_section(task: BehaviorTask, tree: BehaviorTree) -> void:
	var properties := _bindable_properties(task)
	if properties.is_empty():
		return
	var section := VBoxContainer.new()
	var title := Label.new()
	title.text = "Bindings"
	title.add_theme_font_size_override("font_size", 14)
	title.tooltip_text = "Tie a property to a variable. The task then reads and writes the variable."
	section.add_child(title)
	for info in properties:
		var property: String = info["name"]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = property.capitalize()
		label.custom_minimum_size.x = 110.0
		label.clip_text = true
		row.add_child(label)
		var picker := MenuButton.new()
		picker.flat = false
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		picker.clip_text = true
		var current := task.bindings.get(StringName(property), "")
		picker.text = current if not current.is_empty() else "(None)"
		_fill_picker(picker.get_popup(), task, tree, property, int(info["type"]))
		row.add_child(picker)
		section.add_child(row)
	add_custom_control(section)
	add_custom_control(HSeparator.new())


func _fill_picker(popup: PopupMenu, task: BehaviorTask, tree: BehaviorTree, property: String, type: int) -> void:
	popup.add_item("(None)", 0)
	var entries := {}
	for index in tree.variables.size():
		var variable := tree.variables[index]
		if variable and BehaviorGraphOps.types_compatible(variable.type, type):
			popup.add_item(String(variable.name), _VARIABLE_BASE + index)
			entries[_VARIABLE_BASE + index] = String(variable.name)
	var globals := _global_variables()
	var global_index := 0
	for variable in globals:
		if variable and BehaviorGraphOps.types_compatible(variable.type, type):
			if global_index == 0:
				popup.add_separator("Globals")
			popup.add_item("global/%s" % variable.name, _GLOBAL_BASE + global_index)
			entries[_GLOBAL_BASE + global_index] = "global/%s" % variable.name
			global_index += 1
	popup.add_separator()
	popup.add_item("New variable...", _NEW_VARIABLE)
	popup.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			_set_binding(task, property, "")
		elif id == _NEW_VARIABLE:
			_create_variable(task, tree, property, type)
		elif entries.has(id):
			_set_binding(task, property, entries[id]))


func _set_binding(task: BehaviorTask, property: String, variable_name: String) -> void:
	var old: Dictionary = task.bindings.duplicate()
	var updated: Dictionary = old.duplicate()
	if variable_name.is_empty():
		updated.erase(StringName(property))
	else:
		updated[StringName(property)] = variable_name
	if updated == old:
		return
	var tree: BehaviorTree = get_tree_for.call(task) if get_tree_for.is_valid() else null
	undo_redo.create_action("Bind %s" % property.capitalize(), UndoRedo.MERGE_DISABLE, tree if tree else task)
	undo_redo.add_do_property(task, "bindings", updated)
	undo_redo.add_undo_property(task, "bindings", old)
	_add_refresh(task)
	undo_redo.commit_action()


func _create_variable(task: BehaviorTask, tree: BehaviorTree, property: String, type: int) -> void:
	var variable_type := type if type != TYPE_NIL else TYPE_FLOAT
	var variable_name := BehaviorGraphOps.unique_variable_name(tree.variables, property)
	var variable := BehaviorVariable.create(StringName(variable_name), variable_type, task.get(property))
	var old_variables := tree.variables.duplicate()
	var new_variables := tree.variables.duplicate()
	new_variables.append(variable)
	var old: Dictionary = task.bindings.duplicate()
	var updated: Dictionary = old.duplicate()
	updated[StringName(property)] = variable_name
	undo_redo.create_action("New Variable", UndoRedo.MERGE_DISABLE, tree)
	undo_redo.add_do_property(tree, "variables", new_variables)
	undo_redo.add_undo_property(tree, "variables", old_variables)
	undo_redo.add_do_property(task, "bindings", updated)
	undo_redo.add_undo_property(task, "bindings", old)
	_add_refresh(task)
	undo_redo.commit_action()


func _global_variables() -> Array[BehaviorVariable]:
	var path: String = ProjectSettings.get_setting(Behaviors.SETTING_GLOBAL_VARIABLES, "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return []
	var variable_set := load(path) as BehaviorVariableSet
	return variable_set.variables if variable_set else []


func _add_refresh(task: BehaviorTask) -> void:
	undo_redo.add_do_method(task, "notify_property_list_changed")
	undo_redo.add_undo_method(task, "notify_property_list_changed")
	if changed.is_valid():
		undo_redo.add_do_method(changed.get_object(), changed.get_method(), task)
		undo_redo.add_undo_method(changed.get_object(), changed.get_method(), task)


# The exported properties a user can bind: everything the task script adds, except
# task references, variable names and what the task base classes declare.
func _bindable_properties(task: BehaviorTask) -> Array[Dictionary]:
	var skipped := _get_skipped()
	var out: Array[Dictionary] = []
	for info in task.get_property_list():
		var usage: int = info["usage"]
		var property: String = info["name"]
		if not (usage & PROPERTY_USAGE_EDITOR) or not (usage & PROPERTY_USAGE_STORAGE):
			continue
		if skipped.has(property) or property.begins_with("store_") or property.begins_with("metadata/"):
			continue
		if int(info["type"]) == TYPE_NIL and not (usage & PROPERTY_USAGE_NIL_IS_VARIANT):
			continue
		if not _task_class_of(info["type"], info["hint"], info["hint_string"]).is_empty():
			continue
		out.append(info)
	return out


func _get_skipped() -> Dictionary:
	if not _skipped.is_empty():
		return _skipped
	_skipped = {"script": true, "resource_name": true, "resource_path": true, "resource_local_to_scene": true}
	for info in ProjectSettings.get_global_class_list():
		if _BASE_CLASSES.has(String(info["class"])):
			var script := load(String(info["path"])) as Script
			if script:
				for property in script.get_script_property_list():
					_skipped[String(property["name"])] = true
	return _skipped


# The task class a property refers to, or "" when it holds something else.
func _task_class_of(type: int, hint_type: int, hint_string: String) -> String:
	var class_hint := ""
	if type == TYPE_OBJECT and hint_type == PROPERTY_HINT_RESOURCE_TYPE:
		class_hint = hint_string
	elif type == TYPE_ARRAY and hint_type == PROPERTY_HINT_TYPE_STRING:
		class_hint = hint_string.get_slice(":", hint_string.get_slice_count(":") - 1)
	if not class_hint.is_empty() and BehaviorTaskCatalog.class_inherits(class_hint, "BehaviorTask"):
		return class_hint
	return ""
