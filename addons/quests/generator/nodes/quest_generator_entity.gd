@icon("../../icons/quest_generator.svg")
class_name QuestGeneratorEntity
extends QuestEntity
## Lets a quest giver generate quests. Put it on a character that has a
## [QuestGiver] (as a child, sibling, or on the same node's parent), assign an
## entity type and the domains it observes, and add reward systems.
##
## To generate a quest it looks at the entities in its domains, picks the one it
## finds most urgent, plans how the quester can deal with it, and builds a quest
## offered through the giver.

## Emitted before a generated quest is added, so scripts can add facts to the world model.
signal world_model_updating(world_model: QuestWorldModel)
## Emitted after a generated quest is added to the quest giver.
signal generated_quest(quest: Quest)

## Organize quests in this group. Leave blank for no group.
@export var quest_group := ""
## The domain type where this quest giver is located.
@export var domain_type: QuestDomainType
## The domains that this quest giver observes.
@export var domains: Array[QuestDomain] = []
## Don't generate quests about entities that are already in quests in quest journals.
@export var exclude_entities_in_quest_journals := false
## Require the quester to speak to the quest giver to finish the quest.
@export var require_return_to_complete := true
## Allow generated quests to be abandoned.
@export var generate_abandonable_quests := false
## How the urgency of facts is weighted when choosing what to generate a quest about.
@export var goal_selection_mode: QuestUrgentFactSelectionMode = QuestUrgentFactSelectionMode.create(
		QuestUrgentFactSelectionMode.Criterion.SAME_AS_GLOBAL_SETTING, 1)
## The UI content to show above the list of rewards offered for a quest.
@export var rewards_ui_contents: Array[QuestContent] = []
## Reward systems used to reward generated quests. Reward systems that are
## children or siblings of this node are added automatically.
@export var reward_systems: Array[QuestRewardSystem] = []
## Generate a quest on start. Only generates one quest on start. To generate more, call [method generate_quest].
@export var generate_quest_on_start := false
## Generate a quest only if the number of generated quests is smaller than this.
@export var max_quests_to_generate := 1
## Plan quests on a worker thread instead of the main thread. The quest itself
## is still built on the main thread.
@export var use_thread := false
## Seed for the random choices made while planning. 0 uses a random seed.
@export var random_seed := 0

## The planner that generates this entity's quests.
var quest_planner := QuestPlanner.new()
## True while a quest is being generated.
var is_generating := false


func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		QuestGeneratorData.wire_save_callbacks()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	record_reward_systems()
	if generate_quest_on_start:
		# Give time for entities to spawn and initialize.
		await get_tree().process_frame
		await get_tree().process_frame
		if is_inside_tree():
			generate_quest()


func _exit_tree() -> void:
	super._exit_tree()
	quest_planner.cancel_generation()


## The quest list (usually a quest giver) that offers generated quests.
func get_quest_list() -> QuestList:
	return find_quest_list()


## Adds reward systems found as children or siblings to [member reward_systems].
## Reward systems whose process mode is disabled are skipped.
func record_reward_systems() -> void:
	var parent := get_parent()
	var roots: Array[Node] = [self]
	if parent != null:
		roots.append(parent)
	for root in roots:
		for child in root.get_children():
			var reward_system := child as QuestRewardSystem
			if reward_system != null and not reward_systems.has(reward_system) and reward_system.process_mode != Node.PROCESS_MODE_DISABLED:
				reward_systems.append(reward_system)


## The number of procedurally generated quests the quest list contains.
func get_generated_quest_count() -> int:
	var list := get_quest_list()
	if list == null:
		return 0
	var count := 0
	for quest in list.quest_list:
		if quest != null and quest.is_procedurally_generated:
			count += 1
	return count


## Starts generating a quest. The quest is added to the quest list when ready.
func generate_quest() -> void:
	var list := get_quest_list()
	if is_generating or list == null:
		return
	if get_generated_quest_count() >= max_quests_to_generate:
		return
	_apply_manager_settings()
	quest_planner.use_thread = use_thread
	if random_seed != 0:
		quest_planner.rng.seed = random_seed
	var world_model := build_world_model()
	is_generating = true
	quest_planner.generate_quest(self, quest_group, domain_type, world_model, require_return_to_complete,
			rewards_ui_contents, reward_systems, get_existing_quests(), _on_generated_quest,
			goal_selection_mode, generate_abandonable_quests)


## Copies the generator settings of the [QuestManager] to the planner.
func _apply_manager_settings() -> void:
	var manager := QuestManager.instance
	if manager == null:
		QuestGeneratorData.apply_settings() # Makes sure a player domain type exists.
		return
	QuestPlanner.max_simultaneous_planners = manager.max_simultaneous_planners
	QuestPlanner.max_goal_action_checks_per_frame = manager.max_goal_action_checks_per_frame
	QuestPlanner.max_steps_per_frame = manager.max_steps_per_frame
	QuestPlanner.detailed_debug = manager.debug_generator
	# Generator settings the manager may offer, as in the original configuration.
	var player_domain := manager.get(&"default_player_domain_type") as QuestDomainType
	if player_domain != null:
		QuestGeneratorData.default_player_domain_type = player_domain
	var selection := manager.get(&"goal_selection_mode") as QuestUrgentFactSelectionMode
	if selection != null:
		QuestGeneratorData.global_goal_selection = selection
	QuestGeneratorData.apply_settings()


## Quests that the planner should avoid generating goals for.
func get_existing_quests() -> Array[Quest]:
	var existing: Array[Quest] = []
	var list := get_quest_list()
	if list != null:
		existing.append_array(list.quest_list)
	if exclude_entities_in_quest_journals:
		for other: QuestList in Quests.get_all_quest_lists().values():
			if other != null and other != list and other is QuestJournal:
				existing.append_array(other.quest_list)
	return existing


func _on_generated_quest(quest: Quest) -> void:
	is_generating = false
	if quest == null:
		return
	var list := get_quest_list()
	if list != null and is_inside_tree() and get_generated_quest_count() < max_quests_to_generate:
		var added := list.add_quest(quest)
		if added != null:
			generated_quest.emit(added)
			return
	# Not taken: a generated quest is a runtime instance, so it must be disposed of.
	quest.dispose(true)


## Builds the world model from the observed domains, then lets listeners change it.
func build_world_model() -> QuestWorldModel:
	var world_model := build_world_model_from_domains()
	world_model_updating.emit(world_model)
	return world_model


func build_world_model_from_domains() -> QuestWorldModel:
	var world_model := QuestWorldModel.new(QuestFact.new(domain_type, entity_type, 1))
	for domain in domains:
		if domain != null:
			domain.add_entities_to_world_model(world_model)
	return world_model


#region Dialogue

## Generates a quest if the giver has none, then starts dialogue with the player.
func start_dialogue_with_player() -> void:
	start_dialogue(null)


## Generates a quest if the giver has none and none of its quests is active,
## then starts dialogue with [param player]. If null, the giver finds the player journal.
func start_dialogue(player: Node = null) -> void:
	_generate_quest_then_talk(player)


func _generate_quest_then_talk(player: Node) -> void:
	var giver := get_quest_list() as QuestGiver
	if giver == null:
		return
	var journal: QuestJournal = _find_journal(player) if player != null else giver.find_player_journal()
	if journal == null:
		return
	if giver.quest_list.is_empty() and not is_my_quest_active(journal):
		generate_quest()
		var deadline := Time.get_ticks_msec() + 1000 # Give 1 second to generate quest.
		while giver.quest_list.is_empty() and Time.get_ticks_msec() < deadline and is_inside_tree():
			await get_tree().process_frame
	giver.start_dialogue(player)


func _find_journal(node: Node) -> QuestJournal:
	if node is QuestJournal:
		return node
	for child in node.get_children():
		var found := _find_journal(child)
		if found != null:
			return found
	return null


## True if the journal has an active quest that was given by this entity's giver.
func is_my_quest_active(journal: QuestJournal) -> bool:
	var giver := get_quest_list()
	if giver == null or journal == null:
		return false
	for quest in journal.quest_list:
		if quest.get_state() == Quest.State.ACTIVE and quest.quest_giver_id == giver.id:
			return true
	return false

#endregion
