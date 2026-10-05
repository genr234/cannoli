class_name QuestsGeneratorFixture
extends RefCounted
## A small world for generator tests: a villager who hates orcs, orcs to kill, a
## sword to craft that needs iron, and iron to collect in the forest.

var safety := QuestDrive.new()
var villagers := QuestFaction.new()
var orc_faction := QuestFaction.new()

var village := QuestDomainType.new()
var forest := QuestDomainType.new()
var player_domain := QuestDomainType.new()

var player_type := QuestPlayerEntityType.new()
var villager_type := QuestEntityType.new()
var orc_type := QuestEntityType.new()
var iron_type := QuestEntityType.new()
var sword_type := QuestEntityType.new()

var kill := QuestVerb.new()
var collect := QuestVerb.new()
var craft := QuestVerb.new()
var shuffle := QuestVerb.new()


func _init() -> void:
	safety.resource_name = "Safety"
	villagers.resource_name = "Villagers"
	orc_faction.resource_name = "Orcs"
	villagers.set_affinity(orc_faction, -80.0)
	village.resource_name = "Village"
	forest.resource_name = "Forest"
	player_domain.resource_name = "Player"
	player_domain.is_player_domain = true
	player_type.resource_name = "Player"

	villager_type.resource_name = "Villager"
	villager_type.faction = villagers
	villager_type.original_drive_values = [QuestDriveValue.create(safety, 100.0)]

	orc_type.resource_name = "Orc"
	orc_type.level = 5
	orc_type.faction = orc_faction
	orc_type.urgency_functions = [QuestThreatUrgency.new()]
	orc_type.actions = [kill]

	iron_type.resource_name = "Iron"
	iron_type.faction = orc_faction
	iron_type.actions = [collect, shuffle]

	sword_type.resource_name = "Sword"
	sword_type.faction = villagers
	sword_type.urgency_functions = [QuestLiteralUrgency.create(10.0)]
	sword_type.actions = [craft]

	_setup_kill()
	_setup_collect()
	_setup_craft()
	_setup_shuffle()


func this_domain() -> QuestDomainSpecifier:
	return QuestDomainSpecifier.create(QuestDomainSpecifier.Type.THIS_ENTITY_DOMAIN)


func quester_domain() -> QuestDomainSpecifier:
	return QuestDomainSpecifier.create(QuestDomainSpecifier.Type.QUESTER_DOMAIN)


func this_entity() -> QuestEntitySpecifier:
	return QuestEntitySpecifier.create(QuestEntitySpecifier.Type.THIS_ENTITY)


func _setup_kill() -> void:
	kill.resource_name = "Kill"
	kill.display_name = "Kill"
	kill.motives = [QuestMotive.create("Please go to the {DOMAIN} and {Kill} {TARGETDESCRIPTOR}.", [QuestDriveValue.create(safety, 100.0)])]
	kill.requirements = [QuestVerbRequirement.create(this_domain(), this_entity(), 1)]
	kill.effects = [QuestVerbEffect.create(QuestVerbEffect.Operation.REMOVE, this_domain(), this_entity(), 1)]
	kill.completion.mode = QuestVerbCompletion.Mode.COUNTER
	kill.completion.base_counter_name = "Killed"
	kill.completion.min_value = 0
	kill.completion.max_value = 50
	kill.completion.required_value = 1
	kill.completion.message_event_list = [QuestCounterMessageEvent.create("Killed", "{TARGETENTITY}")]
	kill.text.active_text = QuestVerbStateText.create("Kill {#COUNTERGOAL} {TARGETDESCRIPTOR}.", "{#COUNTERNAME}", "Kill {#COUNTERNAME}/{#COUNTERGOAL}", "Go kill them.")
	kill.text.completed_text = QuestVerbStateText.create("They are dead.", "Done killing.", "")
	kill.text.success_text = "Thank you for dealing with the {TARGETDESCRIPTOR}."


func _setup_collect() -> void:
	collect.resource_name = "Collect"
	collect.display_name = "Collect"
	collect.requirements = [QuestVerbRequirement.create(this_domain(), this_entity(), 1)]
	collect.effects = [
		QuestVerbEffect.create(QuestVerbEffect.Operation.REMOVE, this_domain(), this_entity(), 1),
		QuestVerbEffect.create(QuestVerbEffect.Operation.ADD, quester_domain(), this_entity(), 1),
	]
	collect.completion.mode = QuestVerbCompletion.Mode.COUNTER
	collect.completion.base_counter_name = "Collected"
	collect.completion.counter_value_mode = QuestCounterCondition.CounterValueMode.AT_LEAST
	collect.completion.message_event_list = [QuestCounterMessageEvent.create("Got", "{TARGETENTITY}")]
	collect.text.active_text = QuestVerbStateText.create("Collect {TARGETDESCRIPTOR} from the {DOMAIN}.", "", "{#COUNTERNAME}/{#COUNTERGOAL}")


func _setup_craft() -> void:
	craft.resource_name = "Craft"
	craft.display_name = "Craft"
	craft.motives = [QuestMotive.create("I need a {TARGET}.")]
	craft.requirements = [QuestVerbRequirement.create(quester_domain(), QuestEntitySpecifier.other(iron_type), 1)]
	craft.effects = [QuestVerbEffect.create(QuestVerbEffect.Operation.REMOVE, this_domain(), this_entity(), 1)]
	craft.completion.mode = QuestVerbCompletion.Mode.MESSAGE
	craft.completion.message = "Crafted"
	craft.completion.parameter = "{TARGETENTITY}"
	craft.text.active_text = QuestVerbStateText.create("Craft the {TARGET}.", "Craft it.", "Craft the {TARGET}")
	craft.text.completed_text = QuestVerbStateText.create("", "", "")
	craft.text.success_text = "Fine work."


## A verb that returns the world to the state it was in: a loop for the planner to avoid.
func _setup_shuffle() -> void:
	shuffle.resource_name = "Shuffle"
	shuffle.display_name = "Shuffle"
	shuffle.requirements = [QuestVerbRequirement.create(this_domain(), this_entity(), 1)]
	shuffle.effects = [
		QuestVerbEffect.create(QuestVerbEffect.Operation.REMOVE, this_domain(), this_entity(), 1),
		QuestVerbEffect.create(QuestVerbEffect.Operation.ADD, this_domain(), this_entity(), 1),
	]
	shuffle.completion.mode = QuestVerbCompletion.Mode.MESSAGE
	shuffle.completion.message = "Shuffled"


func new_world_model(orcs := 0, iron := 0, swords := 0) -> QuestWorldModel:
	var wm := QuestWorldModel.new(QuestFact.new(village, villager_type, 1))
	if orcs > 0:
		wm.add_entity_type(forest, orc_type, orcs)
	if iron > 0:
		wm.add_entity_type(forest, iron_type, iron)
	if swords > 0:
		wm.add_entity_type(village, sword_type, swords)
	return wm
