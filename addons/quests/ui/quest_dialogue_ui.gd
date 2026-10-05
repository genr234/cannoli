@icon("../icons/quest_ui.svg")
class_name QuestDialogueUI
extends Control
## Base class for quest dialogue UIs, which let a player talk to a quest giver.
## See [QuestDefaultDialogueUI] for the default implementation.

## Emitted when the dialogue closes.
signal closed()

## True while the dialogue is showing.
var is_open: bool:
	get: return visible


## Shows content spoken by [param speaker] with a close button.
func show_contents(_speaker: QuestParticipant, _contents: Array[QuestContent]) -> void:
	pass


## Shows why quests can't be offered: the first quest's "offer conditions unmet"
## content, or [param contents] if none has any.
func show_offer_conditions_unmet(_speaker: QuestParticipant, _contents: Array[QuestContent], _quests: Array[Quest]) -> void:
	pass


## Shows a list of active and offerable quests as buttons. [param select_handler]
## is called with the chosen [Quest].
func show_quest_list(_speaker: QuestParticipant, _active_contents: Array[QuestContent], _active_quests: Array[Quest],
		_offerable_contents: Array[QuestContent], _offerable_quests: Array[Quest], _select_handler: Callable) -> void:
	pass


## Shows a quest's offer with accept and decline buttons. The handlers are called
## with the [Quest].
func show_offer_quest(_speaker: QuestParticipant, _quest: Quest, _accept_handler: Callable, _decline_handler: Callable) -> void:
	pass


## Shows the dialogue of an active quest. [param back_handler] may be invalid, in
## which case there is no back button.
func show_active_quest(_speaker: QuestParticipant, _quest: Quest, _continue_handler: Callable, _back_handler: Callable) -> void:
	pass


## Shows the dialogue of completed quests.
func show_completed_quest(_speaker: QuestParticipant, _quests: Array[Quest]) -> void:
	pass


## Hides the dialogue and emits [signal closed].
func close() -> void:
	hide()
	closed.emit()
