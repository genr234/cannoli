@tool
extends ConfirmationDialog
## Package picker shown by the Cannoli installer plugin.

signal remove_requested

const Installer := preload("installer.gd")

enum State { LOADING, LIST, BUSY, ERROR }
enum Column { NAME, VERSION, SIZE, DESCRIPTION }
enum ItemButton { LINK, UNINSTALL }

var _state := State.LOADING
var _installer: Installer
var _sources: Array = []
var _source := {}
var _notice := ""
var _packages: Array = []
var _by_id := {}
var _items := {}  # id -> TreeItem
var _groups: Array = []  # category TreeItems
var _user_selected := {}  # ids ticked by the user (not just pulled in as dependencies)

var _source_picker: OptionButton
var _search: LineEdit
var _select_all: Button
var _select_none: Button
var _select_updates: Button
var _tree: Tree
var _status: Label
var _progress: ProgressBar
var _retry: Button
var _stop: Button
var _prompt: ConfirmationDialog
var _prompt_ok := Callable()
var _prompt_cancel := Callable()


func _init() -> void:
	title = "Cannoli Installer"
	ok_button_text = "Install"
	cancel_button_text = "Close"
	dialog_hide_on_ok = false
	confirmed.connect(_on_install_pressed)

	var scale := EditorInterface.get_editor_scale()
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", int(8 * scale))
	add_child(vbox)

	var toolbar := HBoxContainer.new()
	vbox.add_child(toolbar)

	var version_label := Label.new()
	version_label.text = "Version:"
	toolbar.add_child(version_label)

	_source_picker = OptionButton.new()
	_source_picker.custom_minimum_size.x = 180 * scale
	_source_picker.item_selected.connect(_on_source_selected)
	toolbar.add_child(_source_picker)

	_search = LineEdit.new()
	_search.placeholder_text = "Search packages"
	_search.clear_button_enabled = true
	_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search.text_changed.connect(func(_text: String) -> void: _apply_filter())
	toolbar.add_child(_search)

	_select_all = _add_toolbar_button(toolbar, "All", "Select every package shown.", _on_select_all)
	_select_none = _add_toolbar_button(toolbar, "None", "Clear the selection.", _on_select_none)
	_select_updates = _add_toolbar_button(toolbar, "Updates", "Select installed packages with a newer version.", _on_select_updates)

	_tree = Tree.new()
	_tree.columns = 4
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.set_column_title(Column.NAME, "Package")
	_tree.set_column_title(Column.VERSION, "Version")
	_tree.set_column_title(Column.SIZE, "Size")
	_tree.set_column_title(Column.DESCRIPTION, "Description")
	_tree.set_column_expand(Column.VERSION, false)
	_tree.set_column_custom_minimum_width(Column.VERSION, int(150 * scale))
	_tree.set_column_expand(Column.SIZE, false)
	_tree.set_column_custom_minimum_width(Column.SIZE, int(80 * scale))
	_tree.set_column_expand_ratio(Column.DESCRIPTION, 2)
	_tree.set_column_clip_content(Column.DESCRIPTION, true)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_edited.connect(_on_item_edited)
	_tree.button_clicked.connect(_on_tree_button_clicked)
	vbox.add_child(_tree)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status)

	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	vbox.add_child(_progress)

	_retry = add_button("Retry", false, "retry")
	_stop = add_button("Stop", false, "stop")
	custom_action.connect(_on_custom_action)

	_prompt = ConfirmationDialog.new()
	_prompt.confirmed.connect(func() -> void: _finish_prompt(_prompt_ok))
	_prompt.canceled.connect(func() -> void: _finish_prompt(_prompt_cancel))
	add_child(_prompt)

	_installer = Installer.new()
	_installer.sources_loaded.connect(_on_sources_loaded)
	_installer.manifest_loaded.connect(_on_manifest_loaded)
	_installer.progress.connect(_on_progress)
	_installer.cancellable_changed.connect(_on_cancellable_changed)
	_installer.install_finished.connect(_on_install_finished)
	_installer.install_cancelled.connect(_on_install_cancelled)
	_installer.uninstalled.connect(_on_uninstalled)
	_installer.failed.connect(_on_failed)
	add_child(_installer)


func _add_toolbar_button(parent: Control, text: String, tooltip: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func open() -> void:
	_search.right_icon = _icon("Search")
	popup_centered(Vector2i(Vector2(880, 520) * EditorInterface.get_editor_scale()))
	if not _installer.is_busy():
		_load_sources()


# --- Loading -------------------------------------------------------------------


func _load_sources() -> void:
	_set_state(State.LOADING)
	_status.text = "Looking for releases…"
	_installer.fetch_sources()


func _on_sources_loaded(sources: Array, warning: String) -> void:
	var previous: String = _source.get("ref", "")
	_sources = sources
	_notice = warning
	_source_picker.clear()
	var selected := -1
	for i in sources.size():
		_source_picker.add_item(sources[i].label, i)
		if sources[i].ref == previous:
			selected = i
	if selected < 0:
		# Default to the newest stable release, else the newest anything.
		selected = 0
		for i in sources.size():
			if not sources[i].prerelease:
				selected = i
				break
	_source_picker.select(selected)
	_on_source_selected(selected)


func _on_source_selected(index: int) -> void:
	_source = _sources[index]
	_set_state(State.LOADING)
	_status.text = "Fetching the package list for %s…" % _source.label
	_installer.fetch_manifest(_source)


func _on_manifest_loaded(packages: Array) -> void:
	_packages = packages
	_populate()
	_set_state(State.LIST)
	if not _notice.is_empty():
		_status.text = "%s Showing %s instead." % [_notice, _source.label]
		_notice = ""
	elif packages.is_empty():
		_status.text = "No packages are available in %s." % _source.label
	else:
		_status.text = "Choose the packages to install."


# --- State ---------------------------------------------------------------------


func _set_state(state: State) -> void:
	_state = state
	var listing := state == State.LIST
	_tree.visible = state == State.LIST or state == State.BUSY
	_progress.visible = state == State.LOADING or state == State.BUSY
	if state == State.LOADING:
		_set_indeterminate(true)
	_retry.visible = state == State.ERROR
	if state != State.BUSY:
		_stop.visible = false
	get_cancel_button().disabled = state == State.BUSY
	_source_picker.disabled = state == State.BUSY or state == State.LOADING
	_search.editable = listing
	for button: Button in [_select_all, _select_none, _select_updates]:
		button.disabled = not listing
	if listing:
		_refresh_checks()
	else:
		_update_ok_button()
		for item: TreeItem in _items.values():
			item.set_editable(Column.NAME, false)


func _set_indeterminate(value: bool) -> void:
	# ProgressBar.indeterminate isn't available in every 4.x release.
	if "indeterminate" in _progress:
		_progress.set("indeterminate", value)


func _update_ok_button() -> void:
	var count := _selected_ids().size()
	ok_button_text = "Install (%d)" % count if count > 0 else "Install"
	get_ok_button().disabled = _state != State.LIST or count == 0


# --- Package list --------------------------------------------------------------


func _populate() -> void:
	_tree.clear()
	_items.clear()
	_groups.clear()
	_by_id.clear()
	for pkg: Dictionary in _packages:
		_by_id[pkg.id] = pkg

	var root := _tree.create_item()
	var categories := {}
	var use_categories := _packages.any(func(pkg: Dictionary) -> bool: return not pkg.category.is_empty())
	for pkg: Dictionary in _packages:
		var parent := root
		if use_categories:
			var category: String = pkg.category if not pkg.category.is_empty() else "Other"
			if not categories.has(category):
				var group := _tree.create_item(root)
				group.set_text(Column.NAME, category)
				for column in _tree.columns:
					group.set_selectable(column, false)
				categories[category] = group
				_groups.append(group)
			parent = categories[category]
		var item := _tree.create_item(parent)
		_fill_item(item, pkg)
		_items[pkg.id] = item

	for id: String in _user_selected.keys():
		if not _by_id.has(id):
			_user_selected.erase(id)
	_refresh_checks()
	_apply_filter()


func _fill_item(item: TreeItem, pkg: Dictionary) -> void:
	var status := _status_of(pkg)
	var record := Installer.read_record(pkg)
	var installed_version := str(record.get("version", ""))
	var base := EditorInterface.get_base_control()

	item.set_cell_mode(Column.NAME, TreeItem.CELL_MODE_CHECK)
	item.set_text(Column.NAME, pkg.name)
	item.set_metadata(Column.NAME, pkg.id)

	var version_text: String = pkg.version if not pkg.version.is_empty() else "—"
	var version_tooltip := ""
	match status:
		"current":
			version_text += " (installed)"
			item.set_custom_color(Column.VERSION, base.get_theme_color("success_color", "Editor"))
		"update":
			version_text = "%s → %s" % [installed_version, pkg.version]
			version_tooltip = "An update is available."
			item.set_custom_color(Column.VERSION, base.get_theme_color("accent_color", "Editor"))
		"downgrade":
			version_text = "%s → %s" % [installed_version, pkg.version]
			version_tooltip = "The installed version is newer than this one."
			item.set_custom_color(Column.VERSION, base.get_theme_color("warning_color", "Editor"))
		"foreign":
			version_text = "not managed"
			version_tooltip = "res://%s exists but wasn't installed by Cannoli. Installing replaces it." % pkg.path
			item.set_custom_color(Column.VERSION, base.get_theme_color("warning_color", "Editor"))
	item.set_text(Column.VERSION, version_text)
	item.set_tooltip_text(Column.VERSION, version_tooltip)

	item.set_text(Column.SIZE, String.humanize_size(pkg.size) if pkg.size > 0 else "—")
	item.set_text_alignment(Column.SIZE, HORIZONTAL_ALIGNMENT_RIGHT)

	var description: String = pkg.description
	var requires := _names(pkg.dependencies.filter(func(dep: String) -> bool: return _by_id.has(dep)))
	if not requires.is_empty():
		description += ("  ·  " if not description.is_empty() else "") + "Requires " + ", ".join(requires)
	item.set_text(Column.DESCRIPTION, description)
	item.set_tooltip_text(Column.DESCRIPTION, description)
	item.add_button(Column.DESCRIPTION, _icon("ExternalLink"), ItemButton.LINK, false, "Open documentation")
	if status != "available":
		item.add_button(Column.DESCRIPTION, _icon("Remove"), ItemButton.UNINSTALL, false, "Uninstall")


## One of "available", "current", "update", "downgrade" or "foreign".
func _status_of(pkg: Dictionary) -> String:
	if not Installer.is_installed(pkg):
		return "available"
	var record := Installer.read_record(pkg)
	if record.is_empty():
		return "foreign"
	match Installer.compare_versions(str(record.get("version", "")), pkg.version):
		-1:
			return "update"
		1:
			return "downgrade"
	return "current"


func _refresh_checks() -> void:
	var required := {}
	for id: String in _user_selected:
		_collect_dependencies(id, required)
	for id: String in _items:
		var item: TreeItem = _items[id]
		item.set_checked(Column.NAME, _user_selected.has(id) or required.has(id))
		item.set_editable(Column.NAME, _state == State.LIST and not required.has(id))
		var dependents := _names(_user_selected.keys().filter(
			func(other: String) -> bool: return id in _by_id[other].dependencies
		))
		item.set_tooltip_text(
			Column.NAME,
			"Required by %s." % ", ".join(dependents) if required.has(id) and not dependents.is_empty()
			else ("Required by another selected package." if required.has(id) else "")
		)
	_select_updates.disabled = _state != State.LIST or not _items.keys().any(
		func(id: String) -> bool: return _status_of(_by_id[id]) == "update"
	)
	_update_ok_button()


func _collect_dependencies(id: String, out: Dictionary) -> void:
	for dep: String in _by_id[id].dependencies:
		if _by_id.has(dep) and not out.has(dep):
			out[dep] = true
			_collect_dependencies(dep, out)


func _apply_filter() -> void:
	var query := _search.text.strip_edges().to_lower()
	for id: String in _items:
		var pkg: Dictionary = _by_id[id]
		var haystack := " ".join([pkg.name, pkg.id, pkg.description, pkg.category]).to_lower()
		_items[id].visible = query.is_empty() or query in haystack
	for group: TreeItem in _groups:
		group.visible = group.get_children().any(func(child: TreeItem) -> bool: return child.visible)


func _selected_ids() -> Array:
	var ids: Array = []
	for id: String in _items:
		if _items[id].is_checked(Column.NAME):
			ids.append(id)
	return ids


func _names(ids: Array) -> PackedStringArray:
	var names := PackedStringArray()
	for id: String in ids:
		names.append(_by_id[id].name if _by_id.has(id) else id)
	return names


func _link_for(pkg: Dictionary) -> String:
	if not pkg.url.is_empty():
		return pkg.url
	return "https://github.com/%s/tree/%s/%s" % [Installer.REPO, _source.ref, pkg.path]


func _icon(name: String) -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon(name, "EditorIcons")


# --- User actions --------------------------------------------------------------


func _on_item_edited() -> void:
	var item := _tree.get_edited()
	var id: String = item.get_metadata(Column.NAME)
	if item.is_checked(Column.NAME):
		_user_selected[id] = true
	else:
		_user_selected.erase(id)
	_refresh_checks()


func _on_select_all() -> void:
	for id: String in _items:
		if _items[id].visible:
			_user_selected[id] = true
	_refresh_checks()


func _on_select_none() -> void:
	_user_selected.clear()
	_refresh_checks()


func _on_select_updates() -> void:
	_user_selected.clear()
	for id: String in _items:
		if _status_of(_by_id[id]) == "update":
			_user_selected[id] = true
	_refresh_checks()


func _on_tree_button_clicked(item: TreeItem, _column: int, id: int, _mouse_button: int) -> void:
	if _state != State.LIST:
		return
	var pkg: Dictionary = _by_id[item.get_metadata(Column.NAME)]
	match id:
		ItemButton.LINK:
			OS.shell_open(_link_for(pkg))
		ItemButton.UNINSTALL:
			_confirm_uninstall(pkg)


func _confirm_uninstall(pkg: Dictionary) -> void:
	var dependents := _names(_items.keys().filter(
		func(other: String) -> bool:
			return Installer.is_installed(_by_id[other]) and pkg.id in _by_id[other].dependencies
	))
	var text := "Uninstall %s?\nres://%s will be moved to the trash." % [pkg.name, pkg.path]
	if not dependents.is_empty():
		text += "\n\nThese installed packages depend on it and may stop working:\n• " + "\n• ".join(dependents)
	_ask("Uninstall package?", text, "Uninstall", func() -> void:
		_set_state(State.BUSY)
		_progress.value = 0.0
		_set_indeterminate(true)
		_status.text = "Uninstalling %s…" % pkg.name
		_installer.uninstall(pkg)
	)


func _on_install_pressed() -> void:
	if _state != State.LIST:
		return
	var packages: Array = []
	var warnings := PackedStringArray()
	for id: String in _selected_ids():
		var pkg: Dictionary = _by_id[id]
		packages.append(pkg)
		match _status_of(pkg):
			"foreign":
				warnings.append("• %s: res://%s wasn't installed by Cannoli and will be replaced." % [pkg.name, pkg.path])
			"downgrade":
				warnings.append("• %s: the installed version (%s) is newer than %s." % [
					pkg.name, Installer.read_record(pkg).get("version", "?"), pkg.version])
	if warnings.is_empty():
		_start_install(packages)
		return
	_ask(
		"Replace existing packages?",
		"%s\n\nReplaced folders are moved to the trash." % "\n".join(warnings),
		"Continue",
		_start_install.bind(packages)
	)


func _start_install(packages: Array) -> void:
	_set_state(State.BUSY)
	_progress.value = 0.0
	_installer.install(packages, _source)


func _on_custom_action(action: StringName) -> void:
	match action:
		&"retry":
			_load_sources()
		&"stop":
			_installer.cancel()


# --- Installer events ----------------------------------------------------------


func _on_progress(fraction: float, message: String) -> void:
	_set_indeterminate(fraction < 0.0)
	if fraction >= 0.0:
		_progress.value = fraction
	_status.text = message


func _on_cancellable_changed(cancellable: bool) -> void:
	_stop.visible = cancellable and _state == State.BUSY


func _on_install_finished(installed: Array, errors: PackedStringArray) -> void:
	_user_selected.clear()
	_populate()
	_set_state(State.LIST)
	var messages := PackedStringArray()
	if not installed.is_empty():
		messages.append("Installed: %s." % ", ".join(_names(installed.map(func(pkg: Dictionary) -> String: return pkg.id))))
	if not errors.is_empty():
		messages.append("Failed: %s." % "; ".join(errors))
	_status.text = " ".join(messages)
	if not installed.is_empty() and errors.is_empty():
		_ask(
			"Remove installer?",
			"Remove the Cannoli installer from this project?\nInstalled packages are kept.",
			"Remove",
			_on_remove_confirmed,
			"Keep"
		)


func _on_install_cancelled() -> void:
	_set_state(State.LIST)
	_status.text = "Installation cancelled. Nothing was changed."


func _on_uninstalled(pkg: Dictionary) -> void:
	_user_selected.erase(pkg.id)
	_populate()
	_set_state(State.LIST)
	_status.text = "Uninstalled %s." % pkg.name


func _on_failed(message: String) -> void:
	_set_state(State.ERROR)
	_status.text = message


func _on_remove_confirmed() -> void:
	hide()
	remove_requested.emit()


# --- Prompts -------------------------------------------------------------------


func _ask(title_text: String, text: String, ok_text: String, on_ok: Callable, cancel_text := "Cancel") -> void:
	_prompt.title = title_text
	_prompt.dialog_text = text
	_prompt.ok_button_text = ok_text
	_prompt.cancel_button_text = cancel_text
	_prompt_ok = on_ok
	_prompt_cancel = Callable()
	_prompt.popup_centered()


func _finish_prompt(callback: Callable) -> void:
	_prompt_ok = Callable()
	_prompt_cancel = Callable()
	if callback.is_valid():
		callback.call()
