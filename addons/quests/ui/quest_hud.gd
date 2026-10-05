class_name QuestHUD
extends Control
## Base class for quest HUDs. Stub; the ui agent replaces this.


func open(_list: QuestList) -> void:
	show()


func close() -> void:
	hide()


func toggle(list: QuestList) -> void:
	if visible:
		close()
	else:
		open(list)


func repaint(_list: QuestList) -> void:
	pass


func is_group_expanded(_group: String) -> bool:
	return true


func toggle_group(_group: String) -> void:
	pass
