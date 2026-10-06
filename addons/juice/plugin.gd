@tool
extends EditorPlugin

const InspectorPlugin := preload("editor/juice_inspector_plugin.gd")
const DebuggerPlugin := preload("editor/juice_debugger_plugin.gd")

## Inspector plugins added on enter and removed on exit. Editor tooling adds its
## plugins to this list in [method _create_inspector_plugins].
var _inspector_plugins: Array[EditorInspectorPlugin] = []
var _debugger_plugin: DebuggerPlugin


func _enter_tree() -> void:
	var added_setting := _register_settings()
	if added_setting:
		ProjectSettings.save()
	_inspector_plugins = _create_inspector_plugins()
	for inspector_plugin in _inspector_plugins:
		add_inspector_plugin(inspector_plugin)
	_debugger_plugin = DebuggerPlugin.new()
	add_debugger_plugin(_debugger_plugin)


func _exit_tree() -> void:
	for inspector_plugin in _inspector_plugins:
		remove_inspector_plugin(inspector_plugin)
	_inspector_plugins.clear()
	remove_debugger_plugin(_debugger_plugin)
	_debugger_plugin = null


func _create_inspector_plugins() -> Array[EditorInspectorPlugin]:
	var inspector_plugin := InspectorPlugin.new()
	inspector_plugin.undo_redo = get_undo_redo()
	return [inspector_plugin]


func _register_settings() -> bool:
	var added := false
	added = _ensure_setting(Juice.SETTING_ENABLED, TYPE_BOOL, true) or added
	for category in Juice.CATEGORIES:
		added = _ensure_setting(Juice.get_setting_path(category), TYPE_FLOAT, 1.0, PROPERTY_HINT_RANGE, "0,2,0.01,or_greater") or added
	added = _ensure_setting(Juice.SETTING_FLASH_RATE_CAP, TYPE_FLOAT, 0.0, PROPERTY_HINT_RANGE, "0,30,0.1,or_greater,suffix:flashes/s") or added
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
