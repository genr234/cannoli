@tool
extends EditorProperty
## Lists a faction's parents by name, with buttons to add and remove them.

var _get_database: Callable
var _box := VBoxContainer.new()


func _init(get_database: Callable) -> void:
	_get_database = get_database
	add_child(_box)
	set_bottom_editor(_box)


func _update_property() -> void:
	for child in _box.get_children():
		child.queue_free()
	var database: FactionDatabase = _get_database.call()
	var faction := get_edited_object() as Faction
	var parents: PackedInt32Array = faction.parents
	for parent_id in parents:
		var row := HBoxContainer.new()
		var label := Label.new()
		var parent := database.get_faction(parent_id) if database != null else null
		label.text = "%s (%d)" % [parent.name, parent_id] if parent != null else "Missing faction (%d)" % parent_id
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		row.add_child(label)
		var remove := Button.new()
		remove.icon = EditorInterface.get_editor_theme().get_icon(&"Remove", &"EditorIcons")
		remove.flat = true
		remove.tooltip_text = "Remove parent"
		remove.disabled = is_read_only()
		remove.pressed.connect(_on_remove_pressed.bind(parent_id))
		row.add_child(remove)
		_box.add_child(row)

	var add := OptionButton.new()
	add.add_item("Add Parent…", -1)
	add.disabled = is_read_only()
	if database != null:
		for candidate in database.factions:
			if candidate == null or candidate.id == faction.id or parents.has(candidate.id):
				continue
			# Skip factions that would create a cycle.
			if database.faction_has_ancestor(candidate.id, faction.id):
				continue
			add.add_item("%s (%d)" % [candidate.name, candidate.id], candidate.id)
	add.item_selected.connect(func(index: int) -> void:
		var id := add.get_item_id(index)
		if id >= 0:
			var updated := parents.duplicate()
			updated.append(id)
			emit_changed(get_edited_property(), updated))
	_box.add_child(add)


func _on_remove_pressed(parent_id: int) -> void:
	var updated: PackedInt32Array = (get_edited_object() as Faction).parents.duplicate()
	updated.remove_at(updated.find(parent_id))
	emit_changed(get_edited_property(), updated)
