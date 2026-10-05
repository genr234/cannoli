@tool
extends EditorPlugin

const QuestEditor := preload("editor/quest_editor.gd")
const QuestContext := preload("editor/quest_context.gd")
const InspectorPlugin := preload("editor/inspector_plugin.gd")
const DebuggerPlugin := preload("editor/debugger_plugin.gd")
const TranslationParser := preload("editor/translation_parser.gd")

var _context: QuestContext
var _editor: QuestEditor
var _inspector_plugin: InspectorPlugin
var _debugger_plugin: DebuggerPlugin
var _translation_parser: TranslationParser


func _enter_tree() -> void:
	_ensure_setting("quests/editor/auto_save", TYPE_BOOL, true)
	_ensure_setting("quests/editor/new_quest_directory", TYPE_STRING, "res://", PROPERTY_HINT_DIR)
	_context = QuestContext.new()
	_debugger_plugin = DebuggerPlugin.new()
	add_debugger_plugin(_debugger_plugin)
	_editor = QuestEditor.new()
	_editor.context = _context
	_editor.undo_redo = get_undo_redo()
	_editor.debugger = _debugger_plugin
	_debugger_plugin.state_received.connect(_editor.on_runtime_state)
	_debugger_plugin.session_stopped.connect(_editor.on_session_stopped)
	EditorInterface.get_editor_main_screen().add_child(_editor)
	_editor.hide()
	_inspector_plugin = InspectorPlugin.new(_context, edit_in_quest_editor)
	add_inspector_plugin(_inspector_plugin)
	_translation_parser = TranslationParser.new()
	add_translation_parser_plugin(_translation_parser)


func _exit_tree() -> void:
	remove_translation_parser_plugin(_translation_parser)
	remove_inspector_plugin(_inspector_plugin)
	remove_debugger_plugin(_debugger_plugin)
	if is_instance_valid(_editor):
		_editor.get_parent().remove_child(_editor)
		_editor.queue_free()
	_editor = null
	_inspector_plugin = null
	_debugger_plugin = null
	_translation_parser = null
	_context = null


func _has_main_screen() -> bool:
	return true


func _get_plugin_name() -> String:
	return "Quests"


func _get_plugin_icon() -> Texture2D:
	return preload("icons/quest.svg")


func _make_visible(visible: bool) -> void:
	if is_instance_valid(_editor):
		_editor.visible = visible


func _handles(object: Object) -> bool:
	return object is Quest or object is QuestDatabase


func _edit(object: Object) -> void:
	if object != null and is_instance_valid(_editor):
		_editor.edit_object(object)


## Opens a quest, database or quest list in the Quests screen.
func edit_in_quest_editor(object: Object) -> void:
	if not is_instance_valid(_editor):
		return
	EditorInterface.set_main_screen_editor("Quests")
	_editor.edit_object(object)


func _ensure_setting(setting_name: String, type: int, default_value: Variant, hint: int = PROPERTY_HINT_NONE, hint_string: String = "") -> void:
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)
	ProjectSettings.set_initial_value(setting_name, default_value)
	ProjectSettings.add_property_info({
		"name": setting_name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	})
