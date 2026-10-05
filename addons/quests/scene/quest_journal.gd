@icon("../icons/quest_journal.svg")
class_name QuestJournal
extends QuestList
## A quester's journal: the quests the quester has accepted, and the UI that
## shows them. The player normally has one.

## The journal UI. If null, the [QuestManager]'s is used.
@export var journal_ui: QuestJournalUI
## The HUD. If null, the [QuestManager]'s is used.
@export var hud: QuestHUD
## Keep completed quests in the journal. If off, they are deleted when they end.
@export var remember_completed_quests := true
## Delete completed generated quests even if completed quests are remembered.
@export var only_remember_handwritten_quests := false
## Remove what UIs no longer need from completed generated quests.
@export var compress_completed_procgen_quests := false
## Tracking a quest stops tracking the others.
@export var only_track_one_quest_at_a_time := false


func _init() -> void:
	forward_events_to_listeners = true


func _enter_tree() -> void:
	super()
	add_to_group(&"quest_journals")
	QuestMessages.add_listener(self, QuestMessages.QUEST_STATE_CHANGED, "", _on_message)
	QuestMessages.add_listener(self, QuestMessages.QUEST_COUNTER_CHANGED, "", _on_message)
	QuestMessages.add_listener(self, QuestMessages.REFRESH_UIS, "", _on_message)
	QuestMessages.add_listener(self, QuestMessages.QUEST_TRACK_TOGGLE_CHANGED, "", _on_message)


func _exit_tree() -> void:
	QuestMessages.remove_listener(self)
	super()


func _ready() -> void:
	super()
	repaint_uis()


## The journal UI in use: this journal's or the manager's.
func get_journal_ui() -> QuestJournalUI:
	if journal_ui != null:
		return journal_ui
	var manager := Quests.get_manager()
	return manager.journal_ui if manager != null else null


## The HUD in use: this journal's or the manager's.
func get_hud() -> QuestHUD:
	if hud != null:
		return hud
	var manager := Quests.get_manager()
	return manager.hud if manager != null else null


func _on_message(args: QuestMessageArgs) -> void:
	if args.sender is Quest and args.sender != find_quest(args.sender.id):
		return # This isn't my instance of the quest.
	match args.message:
		QuestMessages.QUEST_STATE_CHANGED:
			_check_quest_state(args)
			repaint_uis()
		QuestMessages.QUEST_COUNTER_CHANGED, QuestMessages.REFRESH_UIS:
			repaint_uis()
		QuestMessages.QUEST_TRACK_TOGGLE_CHANGED:
			if not check_tracking_toggles(args.parameter):
				repaint_uis()


# Only quest-level state changes: node changes carry a node id as the first value.
func _check_quest_state(args: QuestMessageArgs) -> void:
	if args.values.size() < 2 or not str(args.values[0]).is_empty() or typeof(args.values[1]) != TYPE_INT:
		return
	var quest := find_quest(args.parameter)
	if quest == null:
		return
	var state: int = args.values[1]
	if state == Quest.State.SUCCESSFUL or state == Quest.State.FAILED:
		var should_delete := quest.delete_when_complete or not remember_completed_quests \
				or (only_remember_handwritten_quests and quest.is_procedurally_generated)
		if should_delete:
			delete_quest(quest)
		elif quest.is_procedurally_generated and compress_completed_procgen_quests:
			quest.compress_generated_content()


#region UI

func show_journal_ui() -> void:
	var ui := get_journal_ui()
	if ui != null:
		ui.open(self)


func hide_journal_ui() -> void:
	var ui := get_journal_ui()
	if ui != null:
		ui.close()


func toggle_journal_ui() -> void:
	var ui := get_journal_ui()
	if ui != null:
		ui.toggle(self)


## Repaints the journal UI and the HUD.
func repaint_uis() -> void:
	var ui := get_journal_ui()
	if ui != null:
		ui.repaint(self)
	var tracker := get_hud()
	if tracker != null:
		tracker.repaint(self)

#endregion

#region Tracking and abandoning

## If only one quest can be tracked, untracks the others. Returns true if any changed.
func check_tracking_toggles(quest_id: String) -> bool:
	if not only_track_one_quest_at_a_time:
		return false
	var quest := find_quest(quest_id)
	if quest == null or not quest.show_in_track_hud:
		return false
	var changed := false
	for other in quest_list:
		if other == null or not other.show_in_track_hud or other.id == quest_id:
			continue
		other.show_in_track_hud = false
		changed = true
	if changed:
		QuestMessages.refresh_uis(quest)
	return changed


## Tracks or untracks a quest in the HUD.
func set_tracking(quest_id: String, track: bool) -> void:
	var quest := find_quest(quest_id)
	if quest == null:
		return
	quest.show_in_track_hud = track
	check_tracking_toggles(quest_id)
	repaint_uis()


## Abandons a quest, if it can be abandoned: it becomes ABANDONED if it is
## remembered, or else is deleted.
func abandon_quest(quest: Quest) -> void:
	if quest == null or not quest.is_abandonable:
		return
	var quest_id := quest.id
	if quest.remember_if_abandoned:
		quest.set_state(Quest.State.ABANDONED)
	else:
		quest.execute_state_actions(Quest.State.ABANDONED)
		delete_quest(quest)
	QuestMessages.quest_abandoned(self, quest_id)
	var ui := get_journal_ui()
	if ui != null and ui.is_open:
		ui.select_quest(null)
	repaint_uis()

#endregion

func add_quest(quest: Quest, delay_startup := false) -> Quest:
	var result := super(quest, delay_startup)
	if quest != null:
		check_tracking_toggles(quest.id)
	return result


func apply_data(data: Dictionary) -> void:
	super(data)
	_verify_true_node_children_are_active()
	repaint_uis()


# After loading, children of TRUE nodes in active quests may have been left inactive.
func _verify_true_node_children_are_active() -> void:
	for quest in quest_list:
		if quest.get_state() != Quest.State.ACTIVE:
			continue
		for node in quest.node_list:
			if node.get_state() != QuestNode.State.TRUE:
				continue
			for child in node.child_list:
				if child.get_state() == QuestNode.State.INACTIVE and child.are_join_conditions_met():
					child.set_state(QuestNode.State.ACTIVE)
