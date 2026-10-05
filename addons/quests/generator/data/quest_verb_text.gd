class_name QuestVerbText
extends Resource
## Text for a verb's quest node in its active and completed states.

## Text to use when the task is active.
@export var active_text: QuestVerbStateText = QuestVerbStateText.new()
## Text to use when the task is complete.
@export var completed_text: QuestVerbStateText = QuestVerbStateText.new()
## Text spoken by the quest giver when the quester returns to complete the quest.
@export_multiline var success_text := ""
