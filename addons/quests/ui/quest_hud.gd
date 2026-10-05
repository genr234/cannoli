@icon("../icons/quest_hud.svg")
class_name QuestHUD
extends Control
## Base class for quest HUDs, which show tracked quests during play. See
## [QuestDefaultHUD] for the default implementation.


## Shows the HUD for [param list]'s quests.
func open(_list: QuestList) -> void:
	show()


## Hides the HUD.
func close() -> void:
	hide()


func toggle(list: QuestList) -> void:
	if visible:
		close()
	else:
		open(list)


## Redraws the HUD.
func repaint(_list: QuestList) -> void:
	pass


func is_group_expanded(_group: String) -> bool:
	return true


func toggle_group(_group: String) -> void:
	pass
