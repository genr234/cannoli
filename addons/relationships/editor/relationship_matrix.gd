@tool
extends VBoxContainer
## A factions × factions grid of one relationship trait. Rows are judges,
## columns are subjects. Personal values are solid; inherited ones are faded.
## Click a cell to edit it.

const CELL_SIZE := Vector2(56, 28)

var _database: FactionDatabase
var _title := Label.new()
var _trait_picker := OptionButton.new()
var _show_inherited := CheckBox.new()
var _save_button := Button.new()
var _scroll := ScrollContainer.new()
var _grid := GridContainer.new()
var _popup := PopupPanel.new()
var _popup_label := Label.new()
var _popup_value := SpinBox.new()
var _popup_inheritable := CheckBox.new()
var _editing := Vector2i(-1, -1)
var _refresh_queued := false


func _init() -> void:
	name = "Relationships"
	custom_minimum_size.y = 200

	var toolbar := HBoxContainer.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	toolbar.add_child(_title)
	var trait_label := Label.new()
	trait_label.text = "Trait:"
	toolbar.add_child(trait_label)
	_trait_picker.item_selected.connect(func(_index: int) -> void: refresh())
	toolbar.add_child(_trait_picker)
	_show_inherited.text = "Show Inherited"
	_show_inherited.button_pressed = true
	_show_inherited.toggled.connect(func(_on: bool) -> void: refresh())
	toolbar.add_child(_show_inherited)
	_save_button.text = "Save"
	_save_button.tooltip_text = "Save the faction database resource."
	_save_button.pressed.connect(_save)
	toolbar.add_child(_save_button)
	add_child(toolbar)

	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", 2)
	_grid.add_theme_constant_override(&"v_separation", 2)
	_scroll.add_child(_grid)
	add_child(_scroll)

	var popup_box := VBoxContainer.new()
	popup_box.add_child(_popup_label)
	_popup_value.min_value = -100
	_popup_value.max_value = 100
	_popup_value.step = 0.1
	popup_box.add_child(_popup_value)
	_popup_inheritable.text = "Inheritable"
	_popup_inheritable.tooltip_text = "Whether the judge's sub-factions inherit this relationship."
	popup_box.add_child(_popup_inheritable)
	var buttons := HBoxContainer.new()
	var apply := Button.new()
	apply.text = "Set"
	apply.pressed.connect(_apply_edit)
	buttons.add_child(apply)
	var clear := Button.new()
	clear.text = "Clear (Inherit)"
	clear.tooltip_text = "Remove the judge's own relationship so it inherits again."
	clear.pressed.connect(_clear_edit)
	buttons.add_child(clear)
	popup_box.add_child(buttons)
	_popup.add_child(popup_box)
	add_child(_popup)


func edit(database: FactionDatabase) -> void:
	if _database == database:
		return
	if _database != null and _database.changed.is_connected(_queue_refresh):
		_database.changed.disconnect(_queue_refresh)
	_database = database
	if _database != null:
		_database.changed.connect(_queue_refresh)
	refresh()


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		refresh.call_deferred()


func refresh() -> void:
	_refresh_queued = false
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	if _database == null:
		_title.text = "Select a FactionDatabase to see its relationships."
		_save_button.disabled = true
		return
	_title.text = _database.resource_path.get_file() if not _database.resource_path.is_empty() else "Faction Database"
	_save_button.disabled = not _database.resource_path.begins_with("res://") or _database.resource_path.contains("::")

	var selected_trait := maxi(_trait_picker.selected, 0)
	_trait_picker.clear()
	for definition in _database.relationship_trait_definitions:
		_trait_picker.add_item(definition.name if definition != null else "?")
	if _trait_picker.item_count == 0:
		return
	selected_trait = mini(selected_trait, _trait_picker.item_count - 1)
	_trait_picker.select(selected_trait)

	var factions: Array[Faction] = []
	for faction in _database.factions:
		if faction != null:
			factions.append(faction)
	_grid.columns = factions.size() + 1

	var corner := Label.new()
	corner.text = "judge ↓  subject →"
	corner.modulate.a = 0.6
	_grid.add_child(corner)
	for subject in factions:
		_grid.add_child(_header(subject.name))
	for judge in factions:
		var row_header := _header(judge.name)
		row_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_grid.add_child(row_header)
		for subject in factions:
			_grid.add_child(_cell(judge, subject, selected_trait))


func _header(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.tooltip_text = text
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.clip_text = true
	label.custom_minimum_size = Vector2(CELL_SIZE.x, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _cell(judge: Faction, subject: Faction, trait_id: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = CELL_SIZE
	button.focus_mode = Control.FOCUS_NONE
	var personal := judge.find_personal_relationship(subject.id)
	var value := _database.get_relationship_trait(judge.id, subject.id, trait_id)
	var has_value := personal != null or _database.find_relationship_trait(judge.id, subject.id, trait_id) != null
	var shown := personal != null or (has_value and _show_inherited.button_pressed)
	button.text = ("%d" % roundi(value)) if shown else "·"

	var color := _color_for(value, trait_id)
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	style.bg_color = Color(color, 0.85 if personal != null else (0.3 if shown else 0.08))
	if judge == subject:
		style.border_color = Color(1, 1, 1, 0.25)
		style.set_border_width_all(1)
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		button.add_theme_stylebox_override(state, style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.border_color = Color.WHITE
	hover.set_border_width_all(1)
	button.add_theme_stylebox_override(&"hover", hover)
	if personal == null:
		button.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.6))

	var tooltip := "%s → %s\n%s: %s (%s)" % [judge.name, subject.name, _trait_picker.get_item_text(trait_id),
			snappedf(value, 0.1), "personal" if personal != null else ("inherited" if has_value else "default")]
	if trait_id == Relationship.AFFINITY_TRAIT_INDEX:
		var tier := _database.tier_for_affinity(value)
		if tier != null:
			tooltip += "\nTier: %s" % tier.name
	if personal != null and not personal.inheritable:
		tooltip += "\nNot inheritable"
	button.tooltip_text = tooltip
	button.pressed.connect(_open_editor.bind(judge.id, subject.id, trait_id, button))
	return button


func _color_for(value: float, trait_id: int) -> Color:
	if trait_id == Relationship.AFFINITY_TRAIT_INDEX:
		var tier := _database.tier_for_affinity(value)
		if tier != null:
			return tier.color
	var definition := _database.relationship_trait_definitions[trait_id]
	var low := definition.min_value if definition != null else -100.0
	var high := definition.max_value if definition != null else 100.0
	var t := inverse_lerp(low, high, value) if high > low else 0.5
	return Color("#e5534b").lerp(Color("#a0a8b8"), clampf(t * 2.0, 0.0, 1.0)) if t < 0.5 \
			else Color("#a0a8b8").lerp(Color("#4fbf7f"), clampf(t * 2.0 - 1.0, 0.0, 1.0))


func _open_editor(judge_id: int, subject_id: int, trait_id: int, button: Button) -> void:
	_editing = Vector2i(judge_id, subject_id)
	var judge := _database.get_faction(judge_id)
	var subject := _database.get_faction(subject_id)
	var definition := _database.relationship_trait_definitions[trait_id]
	_popup_label.text = "%s → %s: %s" % [judge.name, subject.name, definition.name if definition != null else "?"]
	_popup_value.min_value = definition.min_value if definition != null else -100.0
	_popup_value.max_value = definition.max_value if definition != null else 100.0
	_popup_value.value = _database.get_relationship_trait(judge_id, subject_id, trait_id)
	var personal := judge.find_personal_relationship(subject_id)
	_popup_inheritable.button_pressed = personal.inheritable if personal != null else true
	_popup.popup(Rect2i(Vector2i(button.get_screen_position() + Vector2(0, button.size.y)), Vector2i.ZERO))
	_popup_value.get_line_edit().grab_focus()


func _apply_edit() -> void:
	_popup.hide()
	var judge := _database.get_faction(_editing.x)
	if judge == null:
		return
	var after := _copy(judge.relationships)
	var relationship: Relationship = null
	for candidate in after:
		if candidate != null and candidate.faction_id == _editing.y:
			relationship = candidate
	if relationship == null:
		var values := PackedFloat32Array()
		values.resize(_database.relationship_trait_definitions.size())
		# Start from what was inherited, so other traits don't jump to 0.
		for trait_id in values.size():
			values[trait_id] = _database.get_relationship_trait(judge.id, _editing.y, trait_id)
		relationship = Relationship.create(_editing.y, values)
		after.append(relationship)
	relationship.set_trait(_trait_picker.selected, _popup_value.value)
	relationship.inheritable = _popup_inheritable.button_pressed
	_commit(judge, after, "Set Relationship")


func _clear_edit() -> void:
	_popup.hide()
	var judge := _database.get_faction(_editing.x)
	if judge == null or not judge.has_personal_relationship(_editing.y):
		return
	var after := _copy(judge.relationships).filter(func(r: Relationship) -> bool: return r == null or r.faction_id != _editing.y)
	var typed: Array[Relationship] = []
	typed.assign(after)
	_commit(judge, typed, "Clear Relationship")


func _copy(relationships: Array[Relationship]) -> Array[Relationship]:
	var result: Array[Relationship] = []
	for relationship in relationships:
		result.append(relationship.duplicate() if relationship != null else null)
	return result


func _commit(judge: Faction, after: Array[Relationship], action: String) -> void:
	var before: Array[Relationship] = judge.relationships.duplicate()
	var undo := EditorInterface.get_editor_undo_redo()
	undo.create_action(action, UndoRedo.MERGE_DISABLE, _database)
	undo.add_do_property(judge, &"relationships", after)
	undo.add_undo_property(judge, &"relationships", before)
	undo.add_do_method(_database, &"emit_changed")
	undo.add_undo_method(_database, &"emit_changed")
	undo.commit_action()


func _save() -> void:
	if _database == null or _database.resource_path.is_empty():
		return
	var error := ResourceSaver.save(_database)
	if error != OK:
		push_error("Relationships: couldn't save %s: %s" % [_database.resource_path, error_string(error)])
