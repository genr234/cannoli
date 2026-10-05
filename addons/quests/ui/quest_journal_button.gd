class_name QuestJournalButton
extends Button
## A button that toggles the player's journal UI. Useful when the journal and the
## journal UI aren't in the same scene. Its methods can also be connected to other
## signals.


func _pressed() -> void:
	toggle_journal_ui()


func toggle_journal_ui() -> void:
	var journal := _get_journal()
	if journal != null:
		journal.toggle_journal_ui()


func show_journal_ui() -> void:
	var journal := _get_journal()
	if journal != null:
		journal.show_journal_ui()


func hide_journal_ui() -> void:
	var journal := _get_journal()
	if journal != null:
		journal.hide_journal_ui()


func _get_journal() -> QuestJournal:
	var journal := Quests.get_journal()
	if journal == null:
		push_warning("Quests: No quest journal found. Cannot toggle journal UI.")
	return journal
