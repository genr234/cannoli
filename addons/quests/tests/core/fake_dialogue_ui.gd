class_name FakeDialogueUI
extends QuestDialogueUI
## A dialogue UI for tests that records what it was asked to show.

var calls: Array[String] = []
var last_quest: Quest
var last_quests: Array[Quest] = []
var accept_handler := Callable()
var decline_handler := Callable()
var continue_handler := Callable()
var back_handler := Callable()
var select_handler := Callable()
var last_contents: Array[QuestContent] = []
var last_active_contents: Array[QuestContent] = []
var last_offerable_contents: Array[QuestContent] = []
var is_showing := false


func last_call() -> String:
	return calls.back() if not calls.is_empty() else ""


func show_contents(_speaker: QuestParticipant, contents: Array[QuestContent]) -> void:
	calls.append("contents")
	last_contents = contents
	is_showing = true


func show_offer_conditions_unmet(_speaker: QuestParticipant, contents: Array[QuestContent], quests: Array[Quest]) -> void:
	calls.append("unmet")
	last_contents = contents
	last_quests = quests
	is_showing = true


func show_quest_list(_speaker: QuestParticipant, active_contents: Array[QuestContent], active_quests: Array[Quest],
		offerable_contents: Array[QuestContent], offerable_quests: Array[Quest], p_select_handler: Callable) -> void:
	calls.append("list")
	last_active_contents = active_contents
	last_offerable_contents = offerable_contents
	last_quests = active_quests + offerable_quests
	select_handler = p_select_handler
	is_showing = true


func show_offer_quest(_speaker: QuestParticipant, quest: Quest, p_accept_handler: Callable, p_decline_handler: Callable) -> void:
	calls.append("offer")
	last_quest = quest
	accept_handler = p_accept_handler
	decline_handler = p_decline_handler
	is_showing = true


func show_active_quest(_speaker: QuestParticipant, quest: Quest, p_continue_handler: Callable, p_back_handler: Callable) -> void:
	calls.append("active")
	last_quest = quest
	continue_handler = p_continue_handler
	back_handler = p_back_handler
	is_showing = true


func show_completed_quest(_speaker: QuestParticipant, quests: Array[Quest]) -> void:
	calls.append("completed")
	last_quests = quests
	is_showing = true


func close() -> void:
	calls.append("close")
	is_showing = false
	closed.emit()
