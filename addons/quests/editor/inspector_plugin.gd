@tool
extends EditorInspectorPlugin
## Nicer editing for quest resources: numbers and message values inline,
## dropdowns for counters, node ids and quest ids, sender and target fields that
## follow their participant, readable summaries for generator resources, and
## validation messages with an "Open in Quest Editor" button.

const NumberProperty := preload("number_property.gd")
const MessageValueProperty := preload("message_value_property.gd")
const NamePickerProperty := preload("name_picker_property.gd")
const NamesPickerProperty := preload("names_picker_property.gd")
const ParticipantIdProperty := preload("participant_id_property.gd")
const QuestContext := preload("quest_context.gd")
const QuestDescribe := preload("quest_describe.gd")

## Classes shown with a generic summary box at the top of the inspector.
const SUMMARY_CLASSES: PackedStringArray = [
	"QuestEntityType", "QuestDomainType", "QuestVerb", "QuestMotive", "QuestDrive", "QuestDriveValue",
	"QuestFaction", "QuestFactionRelationship", "QuestVerbText", "QuestVerbStateText", "QuestVerbRequirement",
	"QuestVerbEffect", "QuestVerbCompletion", "QuestUrgencyFunction", "QuestRequirementFunction",
	"QuestRewardMultiplier", "QuestEntitySpecifier", "QuestDomainSpecifier", "QuestFactSpecifier",
]

var _context: QuestContext
var _open_in_editor: Callable


func _init(context: QuestContext, open_in_editor: Callable) -> void:
	_context = context
	_open_in_editor = open_in_editor


func _can_handle(object: Object) -> bool:
	return object is Quest or object is QuestNode or object is QuestSubasset or object is QuestCounter \
			or object is QuestCounterMessageEvent or object is QuestDatabase or object is QuestList \
			or _is_summary_class(object)


func _parse_begin(object: Object) -> void:
	var problems := PackedStringArray()
	var openable := false
	if object is Quest:
		var known := _context.get_quest_ids()
		problems = PackedStringArray(QuestValidator.validate(object, known))
		openable = true
	elif object is QuestDatabase:
		problems = PackedStringArray(QuestValidator.validate_database(object))
		openable = true
	elif object is QuestList:
		problems = QuestValidator.get_list_warnings(object.quests)
		openable = true
	if openable:
		add_custom_control(_make_header(object, problems))
	if object is QuestNode or _is_summary_class(object):
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.selection_enabled = true
		label.text = QuestDescribe.describe(object)
		add_custom_control(label)


func _parse_property(object: Object, type: Variant.Type, name: String, hint_type: PropertyHint, hint_string: String, usage_flags: int, wide: bool) -> bool:
	if type == TYPE_OBJECT and hint_type == PROPERTY_HINT_RESOURCE_TYPE:
		if hint_string == "QuestNumber":
			add_property_editor(name, NumberProperty.new(_counter_names_for.bind(object)))
			return true
		if hint_string == "QuestMessageValue":
			add_property_editor(name, MessageValueProperty.new())
			return true
	if type == TYPE_STRING:
		return _parse_string_property(object, name)
	if type == TYPE_PACKED_STRING_ARRAY:
		if object is Quest and name == "requires_quests":
			add_property_editor(name, NamesPickerProperty.new(_context.get_quest_ids, object.id))
			return true
		if object is QuestNode and name == "children":
			var quest := _quest_containing(object)
			if quest != null:
				add_property_editor(name, NamesPickerProperty.new(_context.get_node_ids.bind(quest), object.id))
				return true
	return false


func _parse_string_property(object: Object, name: String) -> bool:
	if name == "counter_name" and object is QuestSubasset:
		if _counter_names_for(object).is_empty():
			return false
		add_property_editor(name, NamePickerProperty.new(_counter_names_for.bind(object)))
		return true
	if (name == "quest_id" or name == "required_quest_id") and object is QuestSubasset:
		add_property_editor(name, NamePickerProperty.new(_context.get_quest_ids, "(this quest)"))
		return true
	if (name == "node_id" or name == "required_node_id") and object is QuestSubasset:
		var quest := _target_quest(object)
		if quest == null:
			return false
		add_property_editor(name, NamePickerProperty.new(_context.get_node_ids.bind(quest), "(this node)"))
		return true
	if name == "sender_id" or name == "target_id":
		var specifier := name.replace("_id", "_specifier")
		if specifier in object:
			add_property_editor(name, ParticipantIdProperty.new(specifier, _context.get_participant_ids))
			return true
	return false


func _make_header(object: Object, problems: PackedStringArray) -> Control:
	var box := VBoxContainer.new()
	var button := Button.new()
	button.text = "Edit in Quest Editor"
	button.icon = EditorInterface.get_editor_theme().get_icon("Edit", "EditorIcons")
	button.pressed.connect(_open_in_editor.bind(object))
	box.add_child(button)
	if problems.is_empty():
		return box
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.selection_enabled = true
	var text := "[b]%d problem%s[/b]" % [problems.size(), "" if problems.size() == 1 else "s"]
	for problem in problems:
		text += "\n[color=#e5b34b]-[/color] " + problem.replace("[", "[lb]")
	label.text = text
	box.add_child(label)
	return box


func _is_summary_class(object: Object) -> bool:
	var script: Script = object.get_script()
	while script != null:
		if SUMMARY_CLASSES.has(script.get_global_name()):
			return true
		script = script.get_base_script()
	return false


## The quest that `asset` refers to by quest id, or the quest being edited when
## it has no quest id property or the id is blank.
func _target_quest(asset: Object) -> Quest:
	for property_name in ["required_quest_id", "quest_id"]:
		if property_name in asset:
			var quest_id: String = asset.get(property_name)
			if quest_id.is_empty():
				return _context.current_quest
			return _context.find_quest(quest_id)
	return _context.current_quest


func _counter_names_for(asset: Object) -> PackedStringArray:
	var quest := _target_quest(asset) if asset is QuestSubasset else _context.current_quest
	return _context.get_counter_names(quest)


func _quest_containing(node: QuestNode) -> Quest:
	var quest := _context.current_quest
	if quest != null and quest.node_list.has(node):
		return quest
	for candidate in _context.get_all_quests():
		if candidate.node_list.has(node):
			return candidate
	return null
