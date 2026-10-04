@tool
extends EditorProperty
## Edits a trait array as one named slider per trait definition, with a menu
## to apply presets and, for factions, to inherit the parents' traits.

enum Kind { PERSONALITY, RELATIONSHIP }

enum { MENU_AVERAGE_PARENTS = 1000, MENU_SUM_PARENTS = 1001 }

var _get_database: Callable
var _kind: Kind
var _rows := VBoxContainer.new()
var _sliders: Array[EditorSpinSlider] = []
var _menu := MenuButton.new()


func _init(get_database: Callable, kind: Kind) -> void:
	_get_database = get_database
	_kind = kind
	var box := VBoxContainer.new()
	box.add_child(_rows)
	_menu.text = "Fill From…"
	_menu.flat = false
	_menu.about_to_popup.connect(_fill_menu)
	_menu.get_popup().id_pressed.connect(_on_menu_id_pressed)
	if kind == Kind.PERSONALITY:
		box.add_child(_menu)
	add_child(box)
	set_bottom_editor(box)


func _definitions() -> Array[TraitDefinition]:
	var database: FactionDatabase = _get_database.call()
	if database == null:
		return []
	return database.relationship_trait_definitions if _kind == Kind.RELATIONSHIP else database.personality_trait_definitions


func _current() -> PackedFloat32Array:
	return get_edited_object().get(get_edited_property())


func _update_property() -> void:
	var definitions := _definitions()
	if _sliders.size() != definitions.size():
		_rebuild(definitions)
	var values := _current()
	for i in _sliders.size():
		var definition := definitions[i]
		var slider := _sliders[i]
		slider.label = definition.name if definition != null else "#%d" % i
		slider.tooltip_text = definition.description if definition != null else ""
		slider.min_value = definition.min_value if definition != null else -100.0
		slider.max_value = definition.max_value if definition != null else 100.0
		slider.set_value_no_signal(values[i] if i < values.size() else 0.0)
		slider.read_only = is_read_only()
	_menu.disabled = is_read_only()


func _rebuild(definitions: Array[TraitDefinition]) -> void:
	for child in _rows.get_children():
		child.queue_free()
	_sliders.clear()
	if definitions.is_empty():
		var label := Label.new()
		label.text = "Add trait definitions to the faction database."
		label.modulate.a = 0.6
		_rows.add_child(label)
		return
	for i in definitions.size():
		var slider := EditorSpinSlider.new()
		slider.step = 0.1
		slider.allow_greater = false
		slider.allow_lesser = false
		slider.value_changed.connect(_on_value_changed.bind(i))
		_rows.add_child(slider)
		_sliders.append(slider)


func _on_value_changed(value: float, index: int) -> void:
	var values := _sized(_current())
	values[index] = value
	emit_changed(get_edited_property(), values)


func _sized(values: PackedFloat32Array) -> PackedFloat32Array:
	var result := values.duplicate()
	result.resize(_definitions().size())
	return result


func _fill_menu() -> void:
	var popup := _menu.get_popup()
	popup.clear()
	var database: FactionDatabase = _get_database.call()
	if database == null:
		return
	for i in database.presets.size():
		var preset := database.presets[i]
		if preset != null:
			popup.add_item("Preset: %s" % preset.name, i)
	if get_edited_object() is Faction:
		popup.add_separator()
		popup.add_item("Average of Parents", MENU_AVERAGE_PARENTS)
		popup.add_item("Sum of Parents", MENU_SUM_PARENTS)
		var no_parents: bool = (get_edited_object() as Faction).parents.is_empty()
		popup.set_item_disabled(popup.get_item_index(MENU_AVERAGE_PARENTS), no_parents)
		popup.set_item_disabled(popup.get_item_index(MENU_SUM_PARENTS), no_parents)
	if popup.item_count == 0:
		popup.add_item("No presets in the database", -1)
		popup.set_item_disabled(0, true)


func _on_menu_id_pressed(id: int) -> void:
	var database: FactionDatabase = _get_database.call()
	if database == null:
		return
	if id == MENU_AVERAGE_PARENTS or id == MENU_SUM_PARENTS:
		emit_changed(get_edited_property(), _inherited(database, get_edited_object(), id == MENU_SUM_PARENTS))
	elif 0 <= id and id < database.presets.size():
		emit_changed(get_edited_property(), _sized(database.presets[id].traits))


func _inherited(database: FactionDatabase, faction: Faction, sum: bool) -> PackedFloat32Array:
	var total := _sized(PackedFloat32Array())
	var count := 0
	for parent_id in faction.parents:
		var parent := database.get_faction(parent_id)
		if parent == null:
			continue
		count += 1
		for t in mini(parent.traits.size(), total.size()):
			total[t] += parent.traits[t]
	for t in total.size():
		total[t] = clampf(total[t] if sum or count == 0 else total[t] / count, -100.0, 100.0)
	return total
