@tool
extends ConfirmationDialog
## Package picker shown by the Cannoli installer plugin.

signal remove_requested

const Installer := preload("installer.gd")

enum State { LOADING, LIST, INSTALLING, DONE, ERROR }

var _state := State.LOADING
var _installer: Installer
var _status: Label
var _tree: Tree
var _progress: ProgressBar
var _retry: Button
var _overwrite_dialog: ConfirmationDialog
var _remove_dialog: ConfirmationDialog

var _packages: Array = []
var _by_id := {}
var _items := {}  # id -> TreeItem
var _user_selected := {}  # ids ticked by the user (not just pulled in as dependencies)
var _pending: Array = []


func _init() -> void:
	title = "Cannoli Installer"
	ok_button_text = "Install"
	cancel_button_text = "Close"
	dialog_hide_on_ok = false
	confirmed.connect(_on_install_pressed)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status)

	_tree = Tree.new()
	_tree.columns = 2
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.set_column_title(0, "Package")
	_tree.set_column_title(1, "Description")
	_tree.set_column_expand_ratio(1, 2)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_edited.connect(_on_item_edited)
	vbox.add_child(_tree)

	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	vbox.add_child(_progress)

	_retry = add_button("Retry", false, "retry")
	custom_action.connect(_on_custom_action)

	_overwrite_dialog = ConfirmationDialog.new()
	_overwrite_dialog.title = "Overwrite packages?"
	_overwrite_dialog.ok_button_text = "Overwrite"
	_overwrite_dialog.confirmed.connect(func() -> void: _start_install(_pending))
	add_child(_overwrite_dialog)

	_remove_dialog = ConfirmationDialog.new()
	_remove_dialog.title = "Remove installer?"
	_remove_dialog.dialog_text = "Remove the Cannoli installer from this project?\nInstalled packages are kept."
	_remove_dialog.ok_button_text = "Remove"
	_remove_dialog.cancel_button_text = "Keep"
	_remove_dialog.confirmed.connect(_on_remove_confirmed)
	_remove_dialog.canceled.connect(_on_remove_kept)
	add_child(_remove_dialog)

	_installer = Installer.new()
	_installer.manifest_loaded.connect(_on_manifest_loaded)
	_installer.progress.connect(_on_progress)
	_installer.installed.connect(_on_installed)
	_installer.failed.connect(_on_failed)
	add_child(_installer)


func open() -> void:
	popup_centered(Vector2i(Vector2(640, 420) * EditorInterface.get_editor_scale()))
	if not _installer.is_busy():
		_load()


func _load() -> void:
	_set_state(State.LOADING)
	_status.text = "Fetching package list…"
	_installer.fetch_manifest()


func _set_state(state: State) -> void:
	_state = state
	_tree.visible = state != State.LOADING and state != State.ERROR
	_progress.visible = state == State.INSTALLING or state == State.LOADING
	_set_indeterminate(state == State.LOADING)
	_retry.visible = state == State.ERROR
	get_cancel_button().disabled = state == State.INSTALLING
	if state == State.LIST:
		_refresh_checks()
	else:
		_update_ok_button()
		for item: TreeItem in _items.values():
			item.set_editable(0, false)


func _set_indeterminate(value: bool) -> void:
	# ProgressBar.indeterminate isn't available in every 4.x release.
	if "indeterminate" in _progress:
		_progress.set("indeterminate", value)


func _update_ok_button() -> void:
	get_ok_button().disabled = _state != State.LIST or _selected_ids().is_empty()


func _populate() -> void:
	_tree.clear()
	_items.clear()
	_by_id.clear()
	var root := _tree.create_item()
	for pkg: Dictionary in _packages:
		_by_id[pkg.id] = pkg
		var item := _tree.create_item(root)
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_text(0, pkg.name + (" (installed)" if Installer.is_installed(pkg) else ""))
		item.set_metadata(0, pkg.id)
		item.set_text(1, pkg.description)
		item.set_tooltip_text(1, pkg.description)
		_items[pkg.id] = item
	for id: String in _user_selected.keys():
		if not _by_id.has(id):
			_user_selected.erase(id)
	_refresh_checks()


func _refresh_checks() -> void:
	var required := {}
	for id: String in _user_selected:
		_collect_dependencies(id, required)
	for id: String in _items:
		var item: TreeItem = _items[id]
		item.set_checked(0, _user_selected.has(id) or required.has(id))
		item.set_editable(0, not required.has(id))
		item.set_tooltip_text(0, "Required by another selected package." if required.has(id) else "")
	_update_ok_button()


func _collect_dependencies(id: String, out: Dictionary) -> void:
	for dep: String in _by_id[id].dependencies:
		if _by_id.has(dep) and not out.has(dep):
			out[dep] = true
			_collect_dependencies(dep, out)


func _selected_ids() -> Array:
	var ids: Array = []
	for id: String in _items:
		if _items[id].is_checked(0):
			ids.append(id)
	return ids


func _on_item_edited() -> void:
	var item := _tree.get_edited()
	var id: String = item.get_metadata(0)
	if item.is_checked(0):
		_user_selected[id] = true
	else:
		_user_selected.erase(id)
	_refresh_checks()


func _on_manifest_loaded(packages: Array) -> void:
	_packages = packages
	_populate()
	_set_state(State.LIST)
	_status.text = "Choose the packages to install." if not packages.is_empty() else "No packages are available."


func _on_install_pressed() -> void:
	if _state != State.LIST:
		return
	var packages: Array = []
	var conflicts: PackedStringArray = []
	for id: String in _selected_ids():
		var pkg: Dictionary = _by_id[id]
		packages.append(pkg)
		if Installer.is_installed(pkg):
			conflicts.append("• %s (res://%s)" % [pkg.name, pkg.path])
	if conflicts.is_empty():
		_start_install(packages)
		return
	_pending = packages
	_overwrite_dialog.dialog_text = "These packages are already installed and will be replaced:\n%s\n\nOverwrite?" % "\n".join(conflicts)
	_overwrite_dialog.popup_centered()


func _start_install(packages: Array) -> void:
	_set_state(State.INSTALLING)
	_progress.value = 0.0
	_installer.install(packages)


func _on_progress(fraction: float, message: String) -> void:
	_set_indeterminate(fraction < 0.0)
	if fraction >= 0.0:
		_progress.value = fraction
	_status.text = message


func _on_installed(packages: Array) -> void:
	var names: PackedStringArray = []
	for pkg: Dictionary in packages:
		names.append(pkg.name)
	_user_selected.clear()
	_populate()
	_set_state(State.DONE)
	_status.text = "Installed: %s." % ", ".join(names)
	_remove_dialog.popup_centered()


func _on_failed(message: String) -> void:
	_set_state(State.ERROR)
	_status.text = message


func _on_custom_action(action: StringName) -> void:
	if action == &"retry":
		_load()


func _on_remove_confirmed() -> void:
	hide()
	remove_requested.emit()


func _on_remove_kept() -> void:
	# Let the user install more packages.
	_set_state(State.LIST)
