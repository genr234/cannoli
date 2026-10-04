@tool
extends EditorProperty
## Picks a faction by name.

var _get_database: Callable
var _options := OptionButton.new()


func _init(get_database: Callable) -> void:
	_get_database = get_database
	_options.clip_text = true
	_options.item_selected.connect(_on_item_selected)
	add_child(_options)
	add_focusable(_options)


func _update_property() -> void:
	var current: int = get_edited_object().get(get_edited_property())
	_options.clear()
	var database: FactionDatabase = _get_database.call()
	var found := false
	if database != null:
		for faction in database.factions:
			if faction == null:
				continue
			_options.add_item("%s (%d)" % [faction.name, faction.id], faction.id)
			found = found or faction.id == current
	if not found:
		_options.add_item("Missing faction (%d)" % current, current)
	_options.select(_options.get_item_index(current))
	_options.disabled = is_read_only()


func _on_item_selected(index: int) -> void:
	emit_changed(get_edited_property(), _options.get_item_id(index))
