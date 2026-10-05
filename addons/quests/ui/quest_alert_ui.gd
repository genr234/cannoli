@icon("../icons/quest_ui.svg")
class_name QuestAlertUI
extends Control
## Base class for quest alert UIs, which briefly show messages such as "quest
## started". See [QuestDefaultAlertUI] for the default implementation.


## Shows alert content for a quest.
func show_alert_contents(_quest_id: String, _contents: Array[QuestContent]) -> void:
	pass


## Shows a plain text alert.
func show_alert(_message: String) -> void:
	pass
