@tool
extends EditorPlugin

const InstallerDialog := preload("installer_dialog.gd")
const Remover := preload("remover.gd")
const MENU_ITEM := "Cannoli Installer…"

var _dialog: InstallerDialog


func _enter_tree() -> void:
	add_tool_menu_item(MENU_ITEM, _open)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_ITEM)
	if is_instance_valid(_dialog):
		_dialog.queue_free()
	_dialog = null


func _enable_plugin() -> void:
	# Show the picker right away when the user first enables the plugin.
	if DisplayServer.get_name() != "headless":
		_open.call_deferred()


func _open() -> void:
	if not is_instance_valid(_dialog):
		_dialog = InstallerDialog.new()
		_dialog.remove_requested.connect(_on_remove_requested)
		EditorInterface.get_base_control().add_child(_dialog)
	_dialog.open()


func _on_remove_requested() -> void:
	# Disabling this plugin frees it, so the removal runs from a node it doesn't own.
	var remover := Remover.new()
	EditorInterface.get_base_control().add_child(remover)
	remover.run.call_deferred(get_script().resource_path.get_base_dir())
