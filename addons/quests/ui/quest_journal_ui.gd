class_name QuestJournalUI
extends Control
## Base class for quest journal UIs. Stub; the ui agent replaces this.

var is_open: bool:
	get: return visible


func open(_journal: QuestJournal) -> void:
	show()


func close() -> void:
	hide()


func toggle(journal: QuestJournal) -> void:
	if is_open:
		close()
	else:
		open(journal)


func repaint(_journal: QuestJournal) -> void:
	pass


func is_group_expanded(_group: String) -> bool:
	return true


func toggle_group(_group: String) -> void:
	pass


func select_quest(_quest: Quest) -> void:
	pass
