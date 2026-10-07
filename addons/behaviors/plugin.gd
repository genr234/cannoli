@tool
extends EditorPlugin

const BehaviorEditor := preload("editor/behavior_editor.gd")
const InspectorPlugin := preload("editor/behavior_inspector_plugin.gd")
const DebuggerPlugin := preload("editor/behavior_debugger_plugin.gd")

const ICON_PATH := "res://addons/behaviors/icons/behaviors.svg"

var _editor: BehaviorEditor
var _inspector_plugin: InspectorPlugin
var _debugger_plugin: DebuggerPlugin


func _enter_tree() -> void:
	if _register_settings():
		ProjectSettings.save()
	_editor = BehaviorEditor.new()
	_editor.undo_redo = get_undo_redo()
	EditorInterface.get_editor_main_screen().add_child(_editor)
	_editor.hide()
	_inspector_plugin = InspectorPlugin.new()
	_inspector_plugin.undo_redo = get_undo_redo()
	_inspector_plugin.get_tree_for = _editor.get_tree_for_task
	_inspector_plugin.open_in_editor = edit_in_behaviors
	_inspector_plugin.begin_link = _begin_link
	_inspector_plugin.changed = _editor.notify_task_changed
	add_inspector_plugin(_inspector_plugin)
	_debugger_plugin = DebuggerPlugin.new()
	_debugger_plugin.get_behavior_editor = get_behavior_editor
	_editor.tree_opened.connect(_on_tree_opened)
	add_debugger_plugin(_debugger_plugin)


func _exit_tree() -> void:
	if _debugger_plugin:
		_debugger_plugin.release_all()
		remove_debugger_plugin(_debugger_plugin)
		_debugger_plugin = null
	remove_inspector_plugin(_inspector_plugin)
	if is_instance_valid(_editor):
		_editor.get_parent().remove_child(_editor)
		_editor.queue_free()
	_editor = null
	_inspector_plugin = null


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Behaviors"


func _get_plugin_icon() -> Texture2D:
	if ResourceLoader.exists(ICON_PATH):
		return load(ICON_PATH)
	return EditorInterface.get_editor_theme().get_icon("GraphEdit", "EditorIcons")


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_editor):
		_editor.visible = visible


func _handles(object: Object) -> bool:
	return object is BehaviorTree or object is BehaviorAgent


func _edit(object: Object) -> void:
	if object != null and is_instance_valid(_editor):
		_editor.edit_object(object)


## The Behaviors main screen control. The debugger uses it to draw live state with
## [code]set_runtime_state[/code] and [code]clear_runtime_state[/code].
func get_behavior_editor() -> Control:
	return _editor


## Opens a tree or an agent in the Behaviors screen.
func edit_in_behaviors(object: Object) -> void:
	if not is_instance_valid(_editor):
		return
	EditorInterface.set_main_screen_editor("Behaviors")
	_editor.edit_object(object)


func _on_tree_opened(_tree: BehaviorTree) -> void:
	if _debugger_plugin:
		_debugger_plugin.refresh_overlay()


func _begin_link(task: BehaviorTask, property: StringName, required_class: String) -> void:
	if not is_instance_valid(_editor):
		return
	EditorInterface.set_main_screen_editor("Behaviors")
	_editor.begin_link_mode(task, property, required_class)


func _register_settings() -> bool:
	var added := false
	added = _ensure_setting(Behaviors.SETTING_GLOBAL_VARIABLES, TYPE_STRING, "", PROPERTY_HINT_FILE, "*.tres,*.res") or added
	added = _ensure_setting(Behaviors.SETTING_MAX_AGENTS_PER_FRAME, TYPE_INT, 0, PROPERTY_HINT_RANGE, "0,1000,1,or_greater") or added
	added = _ensure_setting(Behaviors.SETTING_NOISE_LIFETIME, TYPE_FLOAT, 1.0, PROPERTY_HINT_RANGE, "0,10,0.01,or_greater,suffix:s") or added
	added = _ensure_setting(BehaviorEditor.SETTING_AUTO_SAVE, TYPE_BOOL, true) or added
	return added


func _ensure_setting(setting_name: String, type: int, default_value: Variant, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> bool:
	var added := false
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)
		added = true
	ProjectSettings.set_initial_value(setting_name, default_value)
	ProjectSettings.add_property_info({
		"name": setting_name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	})
	return added
