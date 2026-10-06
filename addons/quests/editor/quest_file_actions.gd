@tool
extends RefCounted
## File-backed quest actions of the editor: creating quests (blank, from a
## template, duplicated or imported from JSON), adding existing quest files and
## exporting to JSON. It drives one shared file dialog and reports the results
## through signals; the editor decides where the quests end up.

const QuestFormDialog := preload("quest_form_dialog.gd")
const QuestContext := preload("quest_context.gd")

const SETTING_DIRECTORY := "quests/editor/new_quest_directory"

## A quest file was created or picked and should join the open list.
signal quest_ready(quest: Quest)
## A database file was picked and should be opened as a source.
signal object_chosen(object: Object)

var _dialog: EditorFileDialog
var _form: QuestFormDialog
var _context: QuestContext
var _get_quest: Callable
var _mode := ""
var _pending_template := ""
var _pending_template_params: Dictionary = {}


## `get_quest` returns the quest currently open in the editor.
func _init(dialog: EditorFileDialog, form: QuestFormDialog, context: QuestContext, get_quest: Callable) -> void:
	_dialog = dialog
	_form = form
	_context = context
	_get_quest = get_quest
	_dialog.file_selected.connect(_on_file_selected)


## Asks where to save a new blank quest.
func new_quest() -> void:
	_set_filter("*.tres", "Quest resource")
	_mode = "new"
	_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_dialog.title = "Create Quest"
	_dialog.current_dir = ProjectSettings.get_setting(SETTING_DIRECTORY, "res://")
	_dialog.current_file = "new_quest.tres"
	_dialog.popup_file_dialog()


## Asks for an existing quest or database file.
func add_existing() -> void:
	_set_filter("*.tres", "Quest resource")
	_mode = "existing"
	_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_dialog.title = "Add Existing Quest"
	_dialog.popup_file_dialog()


## Asks where to write the open quest as JSON.
func export_json() -> void:
	var quest: Quest = _get_quest.call()
	if quest == null:
		return
	_mode = "export"
	_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_dialog.title = "Export Quest to JSON"
	_set_filter("*.json", "JSON")
	_dialog.current_file = quest.id + ".json"
	_dialog.popup_file_dialog()


## Asks for a JSON file to import as a new quest.
func import_json() -> void:
	_mode = "import"
	_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_dialog.title = "Import Quest from JSON"
	_set_filter("*.json", "JSON")
	_dialog.popup_file_dialog()


## Opens the template form, then asks where to save the new quest.
func new_from_template(template_id: String) -> void:
	var template: Dictionary = QuestWizards.get_templates()[template_id]
	var fields: Array = template.fields
	_form.open("New Quest: " + template.title, template.help, fields, func(values: Dictionary) -> void:
		_pending_template = template_id
		_pending_template_params = values
		var quest_id: String = values.get("id", "")
		if quest_id.is_empty():
			quest_id = String(values.get("title", template.title)).to_snake_case()
		_set_filter("*.tres", "Quest resource")
		_mode = "template"
		_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
		_dialog.title = "Save New Quest"
		_dialog.current_dir = ProjectSettings.get_setting(SETTING_DIRECTORY, "res://")
		_dialog.current_file = quest_id + ".tres"
		_dialog.popup_file_dialog(), "Create...", QuestWizards.defaults(fields))


## Saves a copy of the open quest next to it under a new id.
func duplicate_quest() -> void:
	var quest: Quest = _get_quest.call()
	if quest == null:
		return
	var copy: Quest = quest.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	copy.id = _unique_quest_id(quest.id + "_copy")
	copy.title = quest.title + " (copy)"
	var base_dir := quest.resource_path.get_base_dir() if not quest.resource_path.is_empty() and not "::" in quest.resource_path else "res://"
	var path := base_dir.path_join(copy.id + ".tres")
	copy.resource_path = ""
	_save_new_quest(copy, path)


func _on_file_selected(path: String) -> void:
	match _mode:
		"new":
			var base := path.get_file().get_basename()
			_save_new_quest(QuestGraphOps.new_quest(base, base.capitalize()), path)
		"existing":
			var loaded := load(path)
			if loaded is Quest:
				quest_ready.emit(loaded)
			elif loaded is QuestDatabase:
				object_chosen.emit(loaded)
			else:
				push_warning("Quests: %s is not a Quest or QuestDatabase." % path)
		"export":
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(QuestSerializer.quest_to_dict(_get_quest.call()), "\t"))
			else:
				push_error("Quests: Could not write %s." % path)
		"import":
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				var imported := QuestSerializer.dict_to_quest(parsed)
				if imported != null:
					imported.id = _unique_quest_id(imported.id)
					_mode = "new"
					_save_new_quest(imported, ProjectSettings.get_setting(SETTING_DIRECTORY, "res://").path_join(imported.id + ".tres"))
			else:
				push_warning("Quests: %s is not a quest JSON file." % path)
		"template":
			var quest := QuestWizards.create_from_template(_pending_template, _pending_template_params)
			if quest != null:
				_save_new_quest(quest, path)


func _set_filter(filter: String, description: String) -> void:
	_dialog.clear_filters()
	_dialog.add_filter(filter, description)


func _save_new_quest(quest: Quest, path: String) -> void:
	ProjectSettings.set_setting(SETTING_DIRECTORY, path.get_base_dir())
	var error := ResourceSaver.save(quest, path, ResourceSaver.FLAG_CHANGE_PATH)
	if error != OK:
		push_error("Quests: Could not save %s (error %d)." % [path, error])
		return
	EditorInterface.get_resource_filesystem().update_file(path)
	_context.mark_dirty()
	quest_ready.emit(quest)


func _unique_quest_id(base: String) -> String:
	var ids := _context.get_quest_ids()
	var candidate := base
	var index := 2
	while ids.has(candidate):
		candidate = "%s_%d" % [base, index]
		index += 1
	return candidate
