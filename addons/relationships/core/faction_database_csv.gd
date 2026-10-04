class_name FactionDatabaseCsv
extends RefCounted
## Exports a [FactionDatabase] to CSV files for editing in a spreadsheet, and
## imports them back.
##
## The folder holds:
## [br]- [code]PersonalityTraits.csv[/code]: name, description
## [br]- [code]RelationshipTraits.csv[/code]: name, description
## [br]- [code]Factions.csv[/code]: ID, name, description, preset flag, color,
## percent judge parents, one column per personality trait, then parent names.
## Rows with the preset flag set to 1 are presets.
## [br]- [code]Relationships_<trait>.csv[/code]: one matrix per relationship
## trait, judges in rows and subjects in columns; "none" means no relationship.

const PERSONALITY_TRAITS_FILE := "PersonalityTraits.csv"
const RELATIONSHIP_TRAITS_FILE := "RelationshipTraits.csv"
const FACTIONS_FILE := "Factions.csv"
const NO_RELATIONSHIP := "none"


## Writes the database's CSV files into [param folder].
static func export_to_folder(database: FactionDatabase, folder: String) -> Error:
	var rows: Array[PackedStringArray] = [PackedStringArray(["Name", "Description"])]
	for definition in database.personality_trait_definitions:
		rows.append(PackedStringArray([definition.name, definition.description]))
	var error := _write(folder.path_join(PERSONALITY_TRAITS_FILE), rows)
	if error != OK:
		return error

	rows = [PackedStringArray(["Name", "Description"])]
	for definition in database.relationship_trait_definitions:
		rows.append(PackedStringArray([definition.name, definition.description]))
	error = _write(folder.path_join(RELATIONSHIP_TRAITS_FILE), rows)
	if error != OK:
		return error

	var heading := PackedStringArray(["ID", "Name", "Description", "Preset", "Color", "%Judge Parents"])
	for definition in database.personality_trait_definitions:
		heading.append(definition.name)
	heading.append("Parents")
	rows = [heading]
	var trait_count := database.personality_trait_definitions.size()
	for preset in database.presets:
		var row := PackedStringArray(["-1", preset.name, preset.description, "1", "", "0"])
		row.append_array(_trait_strings(preset.traits, trait_count))
		rows.append(row)
	for faction in database.factions:
		var row := PackedStringArray([str(faction.id), faction.name, faction.description, "0",
				faction.color.to_html(), str(faction.percent_judge_parents)])
		row.append_array(_trait_strings(faction.traits, trait_count))
		for parent_id in faction.parents:
			var parent := database.get_faction(parent_id)
			if parent != null:
				row.append(parent.name)
			else:
				push_warning("Relationships: faction %s has a parent with ID %d, which isn't in the database." % [faction.name, parent_id])
		rows.append(row)
	error = _write(folder.path_join(FACTIONS_FILE), rows)
	if error != OK:
		return error

	for trait_id in database.relationship_trait_definitions.size():
		var definition := database.relationship_trait_definitions[trait_id]
		heading = PackedStringArray([definition.name])
		for faction in database.factions:
			heading.append(faction.name)
		rows = [heading]
		for judge in database.factions:
			var row := PackedStringArray([judge.name])
			for subject in database.factions:
				var relationship := judge.find_personal_relationship(subject.id)
				row.append(str(relationship.get_trait(trait_id)) if relationship != null else NO_RELATIONSHIP)
			rows.append(row)
		error = _write(folder.path_join(relationship_file_name(definition.name)), rows)
		if error != OK:
			return error
	return OK


## Replaces the database's traits, presets, factions and relationships with
## the CSV files in [param folder]. Missing files are skipped. If
## [param auto_id] is true, factions are numbered in row order instead of
## using the ID column.
static func import_from_folder(database: FactionDatabase, folder: String, auto_id := false) -> Error:
	var rows := _read(folder.path_join(PERSONALITY_TRAITS_FILE))
	if rows.size() > 1:
		var definitions: Array[TraitDefinition] = []
		for row in rows.slice(1):
			definitions.append(TraitDefinition.create(_cell(row, 0), _cell(row, 1)))
		database.personality_trait_definitions = definitions

	rows = _read(folder.path_join(RELATIONSHIP_TRAITS_FILE))
	if rows.size() > 1:
		var definitions: Array[TraitDefinition] = []
		for row in rows.slice(1):
			definitions.append(TraitDefinition.create(_cell(row, 0), _cell(row, 1)))
		database.relationship_trait_definitions = definitions

	var trait_count := database.personality_trait_definitions.size()
	rows = _read(folder.path_join(FACTIONS_FILE))
	if rows.size() > 1:
		var presets: Array[TraitPreset] = []
		var factions: Array[Faction] = []
		var faction_rows: Array[PackedStringArray] = []
		for row in rows.slice(1):
			if _cell(row, 3) == "1":
				var preset := TraitPreset.new()
				preset.name = _cell(row, 1)
				preset.description = _cell(row, 2)
				preset.traits = _parse_traits(row, 6, trait_count)
				presets.append(preset)
				continue
			var faction := Faction.create(factions.size() if auto_id else _cell(row, 0).to_int(), _cell(row, 1), _cell(row, 2))
			var color := _cell(row, 4)
			faction.color = Color.from_string(color, Color.WHITE) if not color.is_valid_int() else Color.WHITE
			faction.percent_judge_parents = _cell(row, 5).to_float()
			faction.traits = _parse_traits(row, 6, trait_count)
			factions.append(faction)
			faction_rows.append(row)
		for i in factions.size():
			var row := faction_rows[i]
			for column in range(6 + trait_count, row.size()):
				for parent in factions:
					if parent.name == row[column]:
						factions[i].parents.append(parent.id)
						break
		database.presets = presets
		database.factions = factions
		var highest := -1
		for faction in factions:
			highest = maxi(highest, faction.id)
		database.next_id = highest + 1

	for trait_id in database.relationship_trait_definitions.size():
		var definition := database.relationship_trait_definitions[trait_id]
		rows = _read(folder.path_join(relationship_file_name(definition.name)))
		if rows.size() < 2:
			continue
		var subjects := rows[0]
		for row in rows.slice(1):
			if row.is_empty():
				continue
			for column in range(1, mini(row.size(), subjects.size())):
				if row[column].is_valid_float():
					database.set_personal_relationship_trait(row[0], subjects[column], trait_id, row[column].to_float())
	database.emit_changed()
	return OK


## The file name for a relationship trait's matrix.
static func relationship_file_name(trait_name: String) -> String:
	return "Relationships_%s.csv" % trait_name.validate_filename()


static func _trait_strings(traits: PackedFloat32Array, count: int) -> PackedStringArray:
	var result := PackedStringArray()
	for i in count:
		result.append(str(traits[i]) if i < traits.size() else "0")
	return result


static func _parse_traits(row: PackedStringArray, first_column: int, count: int) -> PackedFloat32Array:
	var traits := PackedFloat32Array()
	traits.resize(count)
	for i in count:
		traits[i] = _cell(row, first_column + i).to_float()
	return traits


static func _cell(row: PackedStringArray, column: int) -> String:
	return row[column] if column < row.size() else ""


static func _write(path: String, rows: Array[PackedStringArray]) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Relationships: can't write %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()
	for row in rows:
		file.store_csv_line(row)
	return OK


static func _read(path: String) -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	if not FileAccess.file_exists(path):
		return rows
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Relationships: can't read %s: %s" % [path, error_string(FileAccess.get_open_error())])
		return rows
	while not file.eof_reached():
		var row := file.get_csv_line()
		if row.size() == 1 and row[0].is_empty():
			continue
		rows.append(row)
	return rows
