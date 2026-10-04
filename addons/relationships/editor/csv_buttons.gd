@tool
extends HBoxContainer
## Export and import buttons for a faction database's CSV files.

var _database: FactionDatabase
var _importing := false


func _init(database: FactionDatabase) -> void:
	_database = database
	var export_button := Button.new()
	export_button.text = "Export CSV…"
	export_button.tooltip_text = "Write the traits, presets, factions and relationships to CSV files."
	export_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_button.pressed.connect(_choose_folder.bind(false))
	add_child(export_button)
	var import_button := Button.new()
	import_button.text = "Import CSV…"
	import_button.tooltip_text = "Replace this database's contents with CSV files."
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_button.pressed.connect(_choose_folder.bind(true))
	add_child(import_button)


func _choose_folder(importing: bool) -> void:
	_importing = importing
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	dialog.title = "Import CSV Files From Folder" if importing else "Export CSV Files To Folder"
	dialog.dir_selected.connect(_on_dir_selected)
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_file_dialog()


func _on_dir_selected(folder: String) -> void:
	if not _importing:
		if FactionDatabaseCsv.export_to_folder(_database, folder) == OK:
			print("Relationships: exported %s to CSV files in %s." % [_database.resource_path, folder])
		return
	var confirm := ConfirmationDialog.new()
	confirm.title = "Import CSV"
	confirm.dialog_text = "Importing replaces this database's traits, presets, factions and relationships. You can undo it."
	confirm.confirmed.connect(_import.bind(folder))
	confirm.visibility_changed.connect(func() -> void:
		if not confirm.visible:
			confirm.queue_free())
	EditorInterface.get_base_control().add_child(confirm)
	confirm.popup_centered()


func _import(folder: String) -> void:
	var before := _database.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	var after := _database.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as FactionDatabase
	if FactionDatabaseCsv.import_from_folder(after, folder) != OK:
		return
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action("Import Faction Database CSV", UndoRedo.MERGE_DISABLE, _database)
	for property in ["personality_trait_definitions", "relationship_trait_definitions", "presets", "factions", "next_id"]:
		undo.add_do_property(_database, property, after.get(property))
		undo.add_undo_property(_database, property, before.get(property))
	undo.commit_action()
	EditorInterface.inspect_object(_database, "", true)
