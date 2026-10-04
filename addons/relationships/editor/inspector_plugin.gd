@tool
extends EditorInspectorPlugin
## Names trait values, lists factions by name and adds CSV import/export to
## the faction database inspector.

const TraitsProperty := preload("traits_property.gd")
const FactionIdProperty := preload("faction_id_property.gd")
const ParentsProperty := preload("parents_property.gd")
const CsvButtons := preload("csv_buttons.gd")

# The database of the object being inspected. Sub-resources (factions,
# relationships, templates) don't know their database, so they use the one
# from the object that contains them.
var _context: WeakRef = weakref(null)


func _can_handle(object: Object) -> bool:
	var database := _database_for(object)
	if database != null:
		_context = weakref(database)
	return (object is FactionDatabase or object is Faction or object is TraitPreset or object is Relationship
			or object is DeedTemplate or object is DeedOverride or object is FactionMember or object is Traits)


func _parse_begin(object: Object) -> void:
	if object is FactionDatabase:
		add_custom_control(CsvButtons.new(object))


func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint,
		_hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	if _get_database() == null:
		return false
	match name:
		"traits":
			var kind := TraitsProperty.Kind.RELATIONSHIP if object is Relationship else TraitsProperty.Kind.PERSONALITY
			add_property_editor(name, TraitsProperty.new(_get_database, kind))
			return true
		"faction_id", "target_faction_id":
			add_property_editor(name, FactionIdProperty.new(_get_database))
			return true
		"parents":
			if object is Faction:
				add_property_editor(name, ParentsProperty.new(_get_database))
				return true
	return false


func _get_database() -> FactionDatabase:
	var database: FactionDatabase = _context.get_ref()
	if database != null:
		return database
	var root := EditorInterface.get_edited_scene_root()
	if root != null:
		for manager: FactionManager in root.find_children("*", "FactionManager", true, false):
			if manager.faction_database != null:
				return manager.faction_database
	return null


static func _database_for(object: Object) -> FactionDatabase:
	if object is FactionDatabase:
		return object
	if object is DeedTemplateLibrary:
		return object.faction_database
	if object is FactionMember or object is Traits:
		return object.get_database()
	if object is DeedEvaluationOverrides or object is DeedReporter:
		var member: FactionMember = object.member if object.member != null else FactionMember.find_nearest(object)
		if object is DeedReporter and object.deed_template_library != null and object.deed_template_library.faction_database != null:
			return object.deed_template_library.faction_database
		return member.get_database() if member != null else null
	return null
