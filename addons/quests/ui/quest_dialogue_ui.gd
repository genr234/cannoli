class_name QuestDialogueUI
extends Control
## Base class for quest dialogue UIs. Stub; the ui agent replaces this.

signal closed()

var is_open: bool:
	get: return visible


func show_contents(_speaker: QuestParticipant, _contents: Array[QuestContent]) -> void:
	pass


func show_offer_conditions_unmet(_speaker: QuestParticipant, _contents: Array[QuestContent], _quests: Array[Quest]) -> void:
	pass


func show_quest_list(_speaker: QuestParticipant, _active_contents: Array[QuestContent], _active_quests: Array[Quest],
		_offerable_contents: Array[QuestContent], _offerable_quests: Array[Quest], _select_handler: Callable) -> void:
	pass


func show_offer_quest(_speaker: QuestParticipant, _quest: Quest, _accept_handler: Callable, _decline_handler: Callable) -> void:
	pass


func show_active_quest(_speaker: QuestParticipant, _quest: Quest, _continue_handler: Callable, _back_handler: Callable) -> void:
	pass


func show_completed_quest(_speaker: QuestParticipant, _quests: Array[Quest]) -> void:
	pass


func close() -> void:
	hide()
	closed.emit()
