@icon("../icons/quest_journal.svg")
class_name QuestJournalUI
extends Control
## Base class for quest journal UIs, which list a journal's quests and their
## details. See [QuestDefaultJournalUI] for the default implementation.

## True while the journal is showing.
var is_open: bool:
	get: return visible


## Shows the journal UI for [param journal].
func open(_journal: QuestJournal) -> void:
	show()


## Hides the journal UI.
func close() -> void:
	hide()


func toggle(journal: QuestJournal) -> void:
	if is_open:
		close()
	else:
		open(journal)


## Redraws the journal if it is open.
func repaint(_journal: QuestJournal) -> void:
	pass


func is_group_expanded(_group: String) -> bool:
	return true


func toggle_group(_group: String) -> void:
	pass


## Shows [param quest]'s details.
func select_quest(_quest: Quest) -> void:
	pass
