@tool
extends Node
## Disables the installer plugin and deletes its folder.

const Installer := preload("installer.gd")


func run(addon_dir: String) -> void:
	EditorInterface.set_plugin_enabled(addon_dir.path_join("plugin.cfg"), false)
	await get_tree().process_frame

	var err := Installer.remove_dir(addon_dir)
	if err == OK:
		print("Cannoli: installer removed.")
	else:
		push_error("Cannoli: could not remove %s (%s). Delete it manually." % [addon_dir, error_string(err)])

	EditorInterface.get_resource_filesystem().scan()
	queue_free()
