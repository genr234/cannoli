class_name QuestVerbStateText
extends Resource
## Text shown for one state of a verb's quest node, per UI category.

@export_multiline var dialogue_text := ""
@export_multiline var journal_text := ""
@export_multiline var hud_text := ""
@export_multiline var alert_text := ""


static func create(p_dialogue := "", p_journal := "", p_hud := "", p_alert := "") -> QuestVerbStateText:
	var t := QuestVerbStateText.new()
	t.dialogue_text = p_dialogue
	t.journal_text = p_journal
	t.hud_text = p_hud
	t.alert_text = p_alert
	return t
