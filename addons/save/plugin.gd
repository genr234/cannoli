@tool
extends EditorPlugin

const AUTOLOAD_NAME := "Save"
const AUTOLOAD_PATH := "res://addons/save/save.gd"


func _enter_tree() -> void:
	var added_setting := false
	added_setting = _ensure_setting("save/directory", TYPE_STRING, "user://saves") or added_setting
	added_setting = _ensure_setting("save/autosave_enabled", TYPE_BOOL, true) or added_setting
	added_setting = _ensure_setting("save/autosave_seconds", TYPE_FLOAT, 180.0, PROPERTY_HINT_RANGE, "1,86400,1,or_greater,suffix:s") or added_setting
	added_setting = _ensure_setting("save/compress", TYPE_BOOL, true) or added_setting
	added_setting = _ensure_setting("save/encryption_password", TYPE_STRING, "", PROPERTY_HINT_PASSWORD) or added_setting
	added_setting = _ensure_setting("save/version", TYPE_INT, 1, PROPERTY_HINT_RANGE, "1,999999,1") or added_setting
	_ensure_autoload()
	if added_setting:
		ProjectSettings.save()


func _exit_tree() -> void:
	var current := str(ProjectSettings.get_setting("autoload/Save", ""))
	if _is_own_autoload(current):
		remove_autoload_singleton(AUTOLOAD_NAME)


func _ensure_autoload() -> void:
	var current := str(ProjectSettings.get_setting("autoload/Save", ""))
	if _is_own_autoload(current):
		return
	if not current.is_empty():
		push_error("Save: an autoload named Save already exists (%s). Disable it or the Save plugin cannot register." % current)
		return
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _is_own_autoload(value: String) -> bool:
	var path := value.trim_prefix("*")
	if path.begins_with("uid://"):
		var uid := ResourceUID.text_to_id(path)
		return ResourceUID.has_id(uid) and ResourceUID.get_id_path(uid) == AUTOLOAD_PATH
	return path == AUTOLOAD_PATH


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
