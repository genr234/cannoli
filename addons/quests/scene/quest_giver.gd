@icon("../icons/quest_giver.svg")
class_name QuestGiver
extends QuestList
## A quest giver: a character that offers quests and discusses them with a
## quester, using a dialogue UI.
##
## Start a conversation with [method start_dialogue]. The giver looks at the
## quester's journal and shows the most relevant dialogue: a list of quests,
## an offer, an active quest, or what to say when there is nothing to discuss.
## When the player accepts an offer, the quest is copied into the quester's
## journal and started.

enum CompletedQuestDialogueMode { SAME_AS_GLOBAL, SHOW_COMPLETED_QUEST, SHOW_NO_QUESTS }

## Emitted when a dialogue starts. [param player] is the quester.
signal dialogue_started(player: Node)
## Emitted when the dialogue UI closes.
signal dialogue_ended()

## The dialogue UI. If null, the [QuestManager]'s is used.
@export var dialogue_ui: QuestDialogueUI
## This giver's dialect: words used for [code]{Word}[/code] tags in the text of its quests.
## A value may list alternatives separated by [code]|[/code].
@export var text_table: Dictionary[String, String] = {}
## Content to show when there is nothing else to say and no content for that case.
@export var greeting_content: Array[QuestContent]
## Content to show when there are no quests to discuss.
@export var no_quests_content: Array[QuestContent]
## Content shown above the list of offerable quests.
@export var offerable_quests_content: Array[QuestContent]
## Content shown above the list of active quests.
@export var active_quests_content: Array[QuestContent]
@export var completed_quest_dialogue_mode := CompletedQuestDialogueMode.SAME_AS_GLOBAL
## How often, in seconds, to update the cooldowns of the giver's quests. Zero
## updates them only when needed.
@export var cooldown_check_frequency := 1.0:
	set(value):
		cooldown_check_frequency = value
		_cooldown_time = 0.0
		set_process(value > 0.0)

var _non_offerable_quests: Array[Quest] = []
var _offerable_quests: Array[Quest] = []
var _active_quests: Array[Quest] = []
var _completed_quests: Array[Quest] = []
var _player: Node
var _player_participant: QuestParticipant
var _player_list: QuestList
var _allow_back_button := false
var _override_quest_id := ""
var _cooldown_time := 0.0
var _connected_ui: QuestDialogueUI


func _init() -> void:
	forward_events_to_listeners = true


func _ready() -> void:
	super()
	set_process(cooldown_check_frequency > 0.0)
	_delete_unavailable_quests()
	_assign_giver_id_to_quests()
	QuestMessages.refresh_indicators(self)


func _process(delta: float) -> void:
	_cooldown_time += delta
	if _cooldown_time >= cooldown_check_frequency:
		_cooldown_time = 0.0
		update_cooldowns()


## Updates the cooldowns of the quests waiting to start.
func update_cooldowns() -> void:
	for quest in quest_list.duplicate():
		if quest != null and quest.get_state() == Quest.State.WAITING_TO_START:
			quest.update_cooldown()


func reset_to_original_state() -> void:
	super()
	_delete_unavailable_quests()
	_assign_giver_id_to_quests()


## The dialogue UI in use: this giver's or the manager's.
func get_dialogue_ui() -> QuestDialogueUI:
	if dialogue_ui != null:
		return dialogue_ui
	var manager := Quests.get_manager()
	return manager.dialogue_ui if manager != null else null


## The completed quest dialogue mode with SAME_AS_GLOBAL resolved.
## Returns SHOW_COMPLETED_QUEST or SHOW_NO_QUESTS.
func get_participant() -> QuestParticipant:
	var participant := super()
	participant.text_table = text_table
	return participant


func get_completed_quest_dialogue_mode() -> CompletedQuestDialogueMode:
	if completed_quest_dialogue_mode == CompletedQuestDialogueMode.SAME_AS_GLOBAL:
		var manager := Quests.get_manager()
		if manager == null or manager.completed_quest_dialogue_mode == QuestManager.CompletedQuestDialogueMode.SHOW_COMPLETED_QUEST:
			return CompletedQuestDialogueMode.SHOW_COMPLETED_QUEST
		return CompletedQuestDialogueMode.SHOW_NO_QUESTS
	return completed_quest_dialogue_mode


func delete_quest(quest_or_id: Variant) -> void:
	var quest: Quest = quest_or_id if quest_or_id is Quest else find_quest(str(quest_or_id))
	if quest != null:
		quest.clear_indicator_states()
	super(quest_or_id)


func add_quest(quest: Quest, delay_startup := false) -> Quest:
	var instance := super(quest, delay_startup)
	if instance != null:
		instance.assign_quest_giver(get_participant())
		QuestMessages.refresh_uis(self)
	return instance


func _delete_unavailable_quests() -> void:
	for i in range(quest_list.size() - 1, -1, -1):
		var quest := quest_list[i]
		if quest != null and quest.times_accepted >= quest.get_max_times():
			delete_quest(quest)


func _assign_giver_id_to_quests() -> void:
	var participant := get_participant()
	for quest in quest_list:
		if quest != null:
			quest.assign_quest_giver(participant)


#region Finding quests

## True if there is anything to discuss with the quester.
func has_offerable_or_active_quest(player: Node = null) -> bool:
	_record_quests_by_state_for(player)
	return not _offerable_quests.is_empty() or not _active_quests.is_empty()


## The quests this giver can offer the quester.
func get_offerable_quests(player: Node = null) -> Array[Quest]:
	_record_quests_by_state_for(player)
	return _offerable_quests


## The quester's active quests that involve this giver.
func get_active_quests(player: Node = null) -> Array[Quest]:
	_record_quests_by_state_for(player)
	return _active_quests


func _record_quests_by_state_for(player: Node) -> void:
	if player == null:
		player = find_player()
	_player = player
	_setup_player_list()
	record_quests_by_state()


## Sorts the quests into offerable, not offerable, active and completed lists.
func record_quests_by_state() -> void:
	_record_relevant_player_quests()
	_record_offerable_quests()
	_remove_quests_with_no_dialogue(Quest.State.WAITING_TO_START)
	_remove_quests_with_no_dialogue(Quest.State.ACTIVE)


func _record_relevant_player_quests() -> void:
	_active_quests.clear()
	_completed_quests.clear()
	if _player_list == null:
		return
	for quest in _player_list.quest_list:
		if quest == null:
			continue
		var state := quest.get_state()
		if quest.quest_giver_id == id:
			match state:
				Quest.State.ACTIVE:
					_active_quests.append(quest)
				Quest.State.SUCCESSFUL, Quest.State.FAILED:
					_completed_quests.append(quest)
		elif state == Quest.State.ACTIVE and quest.speakers.has(id):
			_active_quests.append(quest)


func _remove_quests_with_no_dialogue(state: Quest.State) -> void:
	var quests := _offerable_quests if state == Quest.State.WAITING_TO_START \
			else _active_quests if state == Quest.State.ACTIVE else _completed_quests
	if quests.is_empty():
		return
	var info := get_participant()
	for i in range(quests.size() - 1, -1, -1):
		var quest := quests[i]
		if quest.quest_giver_id == id:
			continue
		var has_content := not quest.offer_content_list.is_empty() if state == Quest.State.WAITING_TO_START \
				else quest.has_content(QuestContent.Category.DIALOGUE, info)
		if not has_content:
			quests.remove_at(i)


func _record_offerable_quests() -> void:
	_non_offerable_quests.clear()
	_offerable_quests.clear()
	if _player_list == null:
		return
	for quest in quest_list:
		if quest == null or quest.get_state() != Quest.State.WAITING_TO_START:
			continue
		# Is the player already doing a copy of this quest, or a similar generated one?
		var player_copy := _player_list.find_quest(quest.id)
		var is_player_copy_active := player_copy != null and player_copy.get_state() == Quest.State.ACTIVE
		if _is_doing_similar_generated_quest(quest):
			is_player_copy_active = true
		quest.update_cooldown()
		if quest.can_be_offered() and not is_player_copy_active \
				and (player_copy == null or player_copy.times_accepted < quest.get_max_times()):
			if not (quest.no_repeat_if_successful and _player_has_completed(quest.id)):
				_offerable_quests.append(quest)
		elif player_copy == null:
			_non_offerable_quests.append(quest)


func _player_has_completed(quest_id: String) -> bool:
	if quest_id.is_empty() or _player_list == null:
		return false
	var quest := _player_list.find_quest(quest_id)
	return quest != null and quest.get_state() == Quest.State.SUCCESSFUL


func _is_doing_similar_generated_quest(quest: Quest) -> bool:
	if _player_list == null or not quest.is_procedurally_generated:
		return false
	for active in _active_quests:
		if active == null:
			continue
		var tags := active.tag_dictionary
		if tags.has(QuestTags.ACTION) and quest.tag_dictionary.has(QuestTags.ACTION) \
				and tags[QuestTags.ACTION] == quest.tag_dictionary[QuestTags.ACTION] \
				and tags.has(QuestTags.TARGET) and quest.tag_dictionary.has(QuestTags.TARGET) \
				and tags[QuestTags.TARGET] == quest.tag_dictionary[QuestTags.TARGET]:
			return true
	return false

#endregion

#region Finding the player

## The player's journal.
func find_player_journal() -> QuestJournal:
	return Quests.get_journal()


## Finds the quester: the first node in the "player" group that has a quest
## list, else the first node in that group, else the player's journal.
func find_player() -> Node:
	if is_inside_tree():
		var players := get_tree().get_nodes_in_group(&"player")
		for candidate in players:
			if _get_quest_list_of(candidate) != null:
				return candidate
		if not players.is_empty():
			return players[0]
	return find_player_journal()


# The quest list that belongs to a node, without falling back to the player's journal.
func _get_quest_list_of(node: Node) -> QuestList:
	if node == null:
		return null
	if node is QuestList:
		return node
	var identity := QuestIdentity.find_for(node)
	if identity != null and identity.quest_list != null:
		return identity.quest_list
	var found := QuestMessages.find_identifiable(node)
	if found is QuestList:
		return found
	return _find_list_in_children(node)


func _find_list_in_children(node: Node) -> QuestList:
	for child in node.get_children():
		if child is QuestList:
			return child
	for child in node.get_children():
		var found := _find_list_in_children(child)
		if found != null:
			return found
	return null


# Finds the player's quest list and info. Returns false if there isn't one.
func _setup_player_list() -> bool:
	if _player == null:
		_player = find_player()
	if _player == null:
		push_warning("Quests: Can't start dialogue with %s. No quester specified." % name)
		return false
	_player_list = _get_quest_list_of(_player)
	if _player_list == null:
		_player_list = find_player_journal()
	if _player_list == null:
		push_warning("Quests: Can't start dialogue with %s. Quester %s doesn't have a quest journal and can't find one in the scene." % [name, _player.name])
		return false
	return true

#endregion

#region Dialogue

## Starts a dialogue with the quester [param player]. If null, finds the player.
func start_dialogue(player: Node = null) -> void:
	var ui := get_dialogue_ui()
	if ui == null:
		push_warning("Quests: Can't start dialogue with %s. The quest giver doesn't have access to a quest dialogue UI." % name)
		return
	if _connected_ui != ui:
		if _connected_ui != null and _connected_ui.closed.is_connected(_on_dialogue_closed):
			_connected_ui.closed.disconnect(_on_dialogue_closed)
		_connected_ui = ui
		ui.closed.connect(_on_dialogue_closed)
	QuestTags.fallback_text_table = text_table
	_player = player
	if not _setup_player_list():
		return
	_player_participant = QuestParticipant.new(QuestMessages.get_id(_player), QuestMessages.get_display_name(_player))
	dialogue_started.emit(_player)
	# Greet before recording quests, in case the Greet message changes a quest state.
	QuestMessages.greet(_player, self, id)
	record_quests_by_state()
	_start_most_relevant_dialogue()
	# Sent right after opening the UI, not when closing it.
	QuestMessages.greeted(_player, self, id)


func start_dialogue_with_player() -> void:
	start_dialogue(null)


## Starts a dialogue about one quest, whatever its state.
func start_specified_quest_dialogue(player: Node, quest_id: String) -> void:
	_override_quest_id = quest_id
	start_dialogue(player)


func start_specified_quest_dialogue_with_player(quest_id: String) -> void:
	start_specified_quest_dialogue(null, quest_id)


func stop_dialogue() -> void:
	var ui := get_dialogue_ui()
	if ui != null:
		ui.close()


func _on_dialogue_closed() -> void:
	dialogue_ended.emit()


func _find_by_id(list: Array[Quest], quest_id: String) -> Quest:
	for quest in list:
		if quest.id == quest_id:
			return quest
	return null


func _start_most_relevant_dialogue() -> void:
	if not _override_quest_id.is_empty():
		var quest_id := _override_quest_id
		_override_quest_id = ""
		var chosen := _find_by_id(_active_quests, quest_id)
		if chosen != null:
			_show_active_quest(chosen)
			return
		chosen = _find_by_id(_offerable_quests, quest_id)
		if chosen != null:
			_show_offer_quest(chosen)
			return
		chosen = _find_by_id(_non_offerable_quests, quest_id)
		if chosen != null:
			_show_offer_conditions_unmet([chosen])
			return
		chosen = _find_by_id(_completed_quests, quest_id)
		if chosen != null:
			_show_completed_quests([chosen])
			return
	if Quests.debug:
		print("Quests: %s.start_dialogue: #offerable=%d #active=%d #completed=%d" % [name, _offerable_quests.size(), _active_quests.size(), _completed_quests.size()])
	if _active_quests.size() + _offerable_quests.size() >= 2:
		show_quest_list()
	elif _active_quests.size() == 1:
		_show_active_quest(_active_quests[0])
	elif _offerable_quests.size() == 1:
		_show_offer_quest(_offerable_quests[0])
	elif _non_offerable_quests.size() >= 1:
		_show_offer_conditions_unmet(_non_offerable_quests)
	else:
		_remove_quests_with_no_dialogue(Quest.State.SUCCESSFUL)
		if not _completed_quests.is_empty() and get_completed_quest_dialogue_mode() == CompletedQuestDialogueMode.SHOW_COMPLETED_QUEST:
			_show_completed_quests(_completed_quests)
		else:
			_show_no_quests_to_discuss()


func _show_no_quests_to_discuss() -> void:
	get_dialogue_ui().show_contents(get_participant(), no_quests_content if not no_quests_content.is_empty() else greeting_content)


## Shows the list of active and offerable quests to choose from.
func show_quest_list() -> void:
	get_dialogue_ui().show_quest_list(get_participant(), active_quests_content, _active_quests,
			offerable_quests_content, _offerable_quests, _on_select_quest)


func _show_offer_conditions_unmet(quests: Array[Quest]) -> void:
	get_dialogue_ui().show_offer_conditions_unmet(get_participant(),
			no_quests_content if not no_quests_content.is_empty() else greeting_content, quests)


func _show_offer_quest(quest: Quest) -> void:
	var ui := get_dialogue_ui()
	if ui == null:
		push_warning("Quests: There is no quest dialogue UI.")
	elif quest == null:
		push_warning("Quests: The quest passed to show offer is null.")
	elif _player_list == null:
		push_warning("Quests: There is no player quest list. Can't offer quest '%s'." % quest.title)
	else:
		quest.greeter_id = _player_participant.id
		quest.greeter = _player_participant.display_name
		QuestMessages.discuss_quest(_player, self, id, quest.id)
		_player_list.delete_quest(quest.id) # Clear any old instance of repeatable quests first.
		ui.show_offer_quest(get_participant(), quest, _on_accept_quest, _on_quest_back_button)
		QuestMessages.discussed_quest(_player, self, id, quest.id)


func _show_active_quest(quest: Quest) -> void:
	var back_handler := Callable()
	if _active_quests.size() + _offerable_quests.size() >= 2:
		back_handler = _on_quest_back_button
		_allow_back_button = true # May turn in a quest and be left with only one. Still allow the back button.
	quest.greeter_id = _player_participant.id
	quest.greeter = _player_participant.display_name
	QuestMessages.discuss_quest(_player, self, id, quest.id)
	var ui := get_dialogue_ui()
	ui.show_active_quest(get_participant(), quest, _on_continue_active_quest, back_handler)
	QuestMessages.discussed_quest(_player, self, id, quest.id)
	# If this was the only quest, check whether there is a new quest after discussing it.
	if not back_handler.is_valid():
		record_quests_by_state()
		var num_other_active := _active_quests.size()
		if quest.get_state() == Quest.State.ACTIVE:
			num_other_active -= 1
		if num_other_active + _offerable_quests.size() > 0 and ui.has_method(&"set_back_handler"):
			_allow_back_button = true
			ui.call(&"set_back_handler", _on_quest_back_button)


func _show_completed_quests(quests: Array[Quest]) -> void:
	for quest in quests:
		if quest != null and not quest.get_content_list(QuestContent.Category.DIALOGUE).is_empty():
			get_dialogue_ui().show_completed_quest(get_participant(), quests)
			return
	_show_no_quests_to_discuss()


func _on_select_quest(quest: Quest) -> void:
	match quest.get_state():
		Quest.State.WAITING_TO_START:
			_show_offer_quest(quest)
		Quest.State.ACTIVE:
			_show_active_quest(quest)


func _on_accept_quest(quest: Quest) -> void:
	_give_quest_to_list(quest, _player_participant, _player_list)
	record_quests_by_state()
	if _offerable_quests.size() >= 1 and _active_quests.size() + _offerable_quests.size() >= 2:
		show_quest_list()
	else:
		get_dialogue_ui().close()


func _on_quest_back_button(quest: Quest) -> void:
	if _active_quests.has(quest) and quest.get_state() != Quest.State.ACTIVE:
		_active_quests.erase(quest)
	record_quests_by_state()
	if _active_quests.size() + _offerable_quests.size() >= 2 or _allow_back_button:
		show_quest_list()
		_allow_back_button = false
	else:
		get_dialogue_ui().close()


func _on_continue_active_quest(_quest: Quest) -> void:
	get_dialogue_ui().close()

#endregion

#region Giving quests

## Copies [param quest] into a quester's list and starts it. [param quester]
## is a [QuestList], a node that has one, or the id of a list.
func give_quest_to_quester(quest: Quest, quester: Variant) -> void:
	if quest == null:
		push_warning("Quests: %s.give_quest_to_quester - quest is null." % name)
		return
	var target_list: QuestList = null
	var participant: QuestParticipant = null
	if quester is QuestList:
		target_list = quester
		participant = target_list.get_participant()
	elif quester is Node:
		target_list = _get_quest_list_of(quester)
		participant = QuestParticipant.new(QuestMessages.get_id(quester), QuestMessages.get_display_name(quester))
	elif quester != null:
		target_list = Quests.get_quest_list(str(quester))
		participant = target_list.get_participant() if target_list != null else null
	if target_list == null:
		push_warning("Quests: %s.give_quest_to_quester - quester quest list is null." % name)
		return
	_give_quest_to_list(quest, participant, target_list)


## Gives every quest this giver has that the quester doesn't have yet.
func give_all_quests_to_quester(quester: Variant) -> void:
	for i in range(quest_list.size() - 1, -1, -1):
		var quest := quest_list[i]
		var target: QuestList = quester if quester is QuestList \
				else _get_quest_list_of(quester) if quester is Node \
				else Quests.get_quest_list(str(quester))
		if target == null:
			return
		if quest != null and not target.contains_quest(quest.id):
			give_quest_to_quester(quest, target)


func _give_quest_to_list(quest: Quest, quester_info: QuestParticipant, quester_list: QuestList) -> void:
	if quest == null or quester_info == null or quester_list == null:
		push_warning("Quests: %s can't give the quest: the quest, quester info or quester list is null." % name)
		return
	# Make a copy of the quest for the quester.
	var instance := quest.clone()
	# Update the version on this quest giver.
	quest.times_accepted += 1
	if quest.times_accepted >= quest.get_max_times():
		delete_quest(quest)
	else:
		quest.start_cooldown()
	# Add the copy to the quester and activate it.
	instance.assign_quest_giver(get_participant())
	instance.assign_quester(quester_info)
	instance.times_accepted = 1
	for i in range(quester_list.quest_list.size() - 1, -1, -1):
		var in_journal := quester_list.quest_list[i]
		if in_journal != null and in_journal.id == quest.id and in_journal.get_state() != Quest.State.ACTIVE:
			instance.times_accepted += 1
			quester_list.delete_quest(in_journal)
	quester_list.deleted_static_quests.erase(instance.id)
	quester_list.add_quest(instance)
	instance.set_state(Quest.State.ACTIVE)
	QuestMessages.refresh_indicators(instance)

#endregion
