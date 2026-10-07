@icon("../icons/quest_journal.svg")
class_name QuestDefaultJournalUI
extends QuestJournalUI
## The default quest journal UI: a list of the journal's quests grouped in
## foldouts (active quests first, then completed ones) next to a details panel
## with the selected quest's journal content, a track toggle and an abandon button
## with a confirmation panel.
##
## Expects the nodes of [code]quest_journal_ui.tscn[/code] (unique names
## [code]%SelectionContainer[/code], [code]%Details[/code], [code]%EntityName[/code],
## [code]%EntityImage[/code], [code]%TrackButton[/code], [code]%AbandonButton[/code],
## [code]%CloseButton[/code], [code]%AbandonPanel[/code], [code]%AbandonNameLabel[/code],
## [code]%ConfirmAbandonButton[/code], [code]%CancelAbandonButton[/code]).
## [code]ui_cancel[/code] closes the journal (or the abandon confirmation).

## When to send [member open_message] and [member close_message].
enum SendMessageOnOpen { NEVER, ALWAYS, NOT_WHEN_USING_MOUSE }

## Emitted when a quest is selected to show its details.
signal quest_selected(quest: Quest)

@export_group("Selection Panel")
## Show all groups expanded.
@export var always_expand_all_groups := false
## Show details when the pointer hovers or focus lands on a quest name.
@export var show_details_on_focus := false
## Include completed quests in the selection panel.
@export var show_completed_quests := true
## Optional [QuestFoldout] scene for groups.
@export var group_template: PackedScene
## Optional [QuestNameButton] scene for active quests.
@export var active_quest_name_template: PackedScene
## Optional [QuestNameButton] scene for completed quests.
@export var completed_quest_name_template: PackedScene
@export_group("Details Panel")
## Show the Track toggle in the quest details.
@export var show_track_button_in_details := false
@export_group("Misc")
@export var sort_alphabetically := true
## Show the journal's display name in the heading.
@export var show_display_name_in_heading := false
@export var show_dialogue_content_if_no_journal_content := false
@export var show_offer_content_if_no_journal_or_dialogue_content := false
## If false, quests with one or no content are left out of the list.
@export var show_quests_that_have_no_content := true
## Select the first quest when the journal opens and nothing is selected.
@export var show_first_quest_details_on_open := true
@export var send_message_on_open := SendMessageOnOpen.NOT_WHEN_USING_MOUSE
## Shown in the details panel when the journal has no quests to list.
@export var no_quests_text := "You have no quests."
## Shown in the details panel when no quest is selected.
@export var no_selection_text := "Select a quest to see its details."
## Message sent when the journal opens, e.g. to pause the player.
@export var open_message := "Pause Player"
@export var close_message := "Unpause Player"

## The journal being shown.
var journal: QuestJournal
## The quest whose details are shown.
var selected_quest: Quest

var _collapsed_groups: Array[String] = []
var _refresh_pending := false
var _must_send_close_message := false
var _just_shown := false
var _just_toggled_tracking := false
var _using_mouse := true
var _focus_target: Control
var _focused_quest: Quest
var _focused_track_toggle := false

@onready var selection_container: VBoxContainer = %SelectionContainer
@onready var details: QuestContentView = %Details
@onready var entity_name: Label = %EntityName
@onready var entity_image: TextureRect = %EntityImage
@onready var track_button: CheckButton = %TrackButton
@onready var abandon_button: Button = %AbandonButton
@onready var close_button: Button = %CloseButton
@onready var abandon_panel: Control = %AbandonPanel
@onready var abandon_name_label: Label = %AbandonNameLabel
@onready var confirm_abandon_button: Button = %ConfirmAbandonButton
@onready var cancel_abandon_button: Button = %CancelAbandonButton


func _ready() -> void:
	close_button.pressed.connect(close)
	track_button.toggled.connect(_on_details_track_toggled)
	abandon_button.pressed.connect(open_abandon_quest_confirmation_dialog)
	confirm_abandon_button.pressed.connect(confirm_abandon_quest)
	cancel_abandon_button.pressed.connect(_close_abandon_panel)
	abandon_panel.hide()
	track_button.hide()
	abandon_button.hide()
	for message in [QuestMessages.REFRESH_UIS, QuestMessages.QUEST_STATE_CHANGED,
			QuestMessages.QUEST_COUNTER_CHANGED, QuestMessages.QUEST_TRACK_TOGGLE_CHANGED,
			QuestMessages.TIMER_TICK]:
		QuestMessages.add_listener(self, message, "", _on_message)


func _exit_tree() -> void:
	QuestMessages.remove_listener(self)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton or event is InputEventMouseMotion:
		_using_mouse = true
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_using_mouse = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	if abandon_panel.visible:
		_close_abandon_panel()
	else:
		close()
	get_viewport().set_input_as_handled()


func open(p_journal: QuestJournal) -> void:
	journal = p_journal
	show()
	_must_send_close_message = _should_send_open_close_message()
	_just_shown = true
	if _must_send_close_message:
		QuestMessages.send(self, null, open_message, "")
	if selected_quest != null and not _quest_in_journal(selected_quest):
		selected_quest = null
	refresh_now()


## Opens the journal and selects [param quest] (or the quest with that id).
func open_with_quest(p_journal: QuestJournal, quest: Variant) -> void:
	open(p_journal)
	if quest is String and p_journal != null:
		select_quest(p_journal.find_quest(quest))
	elif quest is Quest:
		select_quest(quest)


func close() -> void:
	_close_abandon_panel()
	hide()
	if _must_send_close_message:
		QuestMessages.send(self, null, close_message, "")
	_must_send_close_message = false


func toggle(p_journal: QuestJournal) -> void:
	if is_open:
		close()
	else:
		open(p_journal)


func repaint(p_journal: QuestJournal) -> void:
	journal = p_journal
	_schedule_refresh()


func is_group_expanded(group: String) -> bool:
	return always_expand_all_groups or not _collapsed_groups.has(group)


func toggle_group(group: String) -> void:
	if is_group_expanded(group):
		_collapsed_groups.append(group)
	else:
		_collapsed_groups.erase(group)


func select_quest(quest: Quest) -> void:
	selected_quest = quest
	_update_selection_highlight()
	_repaint_selected_quest()
	quest_selected.emit(quest)


## Toggles whether the selected quest is tracked in the HUD.
func toggle_tracking() -> void:
	if selected_quest != null and selected_quest.is_trackable:
		_on_toggle_tracking(selected_quest, not selected_quest.show_in_track_hud)


## Opens the confirmation panel for abandoning the selected quest.
func open_abandon_quest_confirmation_dialog() -> void:
	if selected_quest == null:
		return
	abandon_name_label.text = QuestUIHelpers.get_title(selected_quest)
	abandon_panel.show()
	cancel_abandon_button.grab_focus()


## Abandons the selected quest.
func confirm_abandon_quest() -> void:
	_close_abandon_panel()
	if journal == null or selected_quest == null:
		return
	journal.abandon_quest(selected_quest)
	refresh_now()


## Redraws immediately instead of at the end of the frame.
func refresh_now() -> void:
	_refresh_pending = false
	if journal == null:
		return
	_focus_target = null
	_remember_focused_row()
	for child in selection_container.get_children():
		selection_container.remove_child(child)
		child.queue_free()
	_refresh_heading()
	var group_names := _get_group_names()
	var num_groupless := _count_groupless()
	_add_quests_to_ui(group_names, num_groupless)
	if _just_shown and show_first_quest_details_on_open and selected_quest == null:
		var first_row := _find_first_quest_control()
		if first_row != null:
			selected_quest = (first_row.get_parent() as QuestNameButton).quest
			_focus_target = first_row
	_update_selection_highlight()
	_repaint_selected_quest()
	if _focus_target == null and _just_shown and visible:
		_focus_target = _find_first_quest_control()
	if _focus_target != null and is_visible_in_tree():
		_focus_target.grab_focus.call_deferred()
	_just_shown = false
	_focused_quest = null


# Rows are rebuilt on every refresh, so note which quest row had focus to
# give it focus again afterwards.
func _remember_focused_row() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var row := focused.get_parent() as QuestNameButton if focused != null else null
	if row != null and selection_container.is_ancestor_of(row):
		_focused_quest = row.quest
		_focused_track_toggle = focused == row.track_toggle


func _update_selection_highlight() -> void:
	for row in selection_container.find_children("*", "QuestNameButton", true, false):
		(row as QuestNameButton).set_selected((row as QuestNameButton).quest == selected_quest)


func _schedule_refresh() -> void:
	if _refresh_pending or not visible:
		return
	_refresh_pending = true
	_refresh_deferred.call_deferred()


func _refresh_deferred() -> void:
	if _refresh_pending and visible:
		refresh_now()


func _on_message(args: QuestMessageArgs) -> void:
	if not visible or journal == null:
		return
	if args.message == QuestMessages.TIMER_TICK:
		if selected_quest != null and QuestUIHelpers.wants_time_remaining(selected_quest):
			_repaint_selected_quest()
		return
	_schedule_refresh()


func _should_send_open_close_message() -> bool:
	match send_message_on_open:
		SendMessageOnOpen.ALWAYS:
			return true
		SendMessageOnOpen.NOT_WHEN_USING_MOUSE:
			return not _using_mouse
	return false


func _refresh_heading() -> void:
	var participant := journal.get_participant()
	entity_image.texture = participant.image if participant != null else null
	entity_image.visible = entity_image.texture != null
	if show_display_name_in_heading and not journal.display_name.is_empty():
		entity_name.text = journal.display_name
	entity_name.visible = not entity_name.text.is_empty()


func _is_listed(quest: Quest) -> bool:
	if quest == null or quest.get_state() == Quest.State.WAITING_TO_START:
		return false
	return show_completed_quests or not QuestUIHelpers.is_completed_state(quest.get_state())


func _get_group_names() -> Array[String]:
	var names: Array[String] = []
	for quest in journal.quest_list:
		if _is_listed(quest) and not quest.group.is_empty() and not names.has(quest.group):
			names.append(quest.group)
	if sort_alphabetically:
		names.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	return names


func _count_groupless() -> int:
	var count := 0
	for quest in journal.quest_list:
		if _is_listed(quest) and quest.group.is_empty():
			count += 1
	return count


func _add_quests_to_ui(group_names: Array[String], num_groupless: int) -> void:
	var quests: Array[Quest] = journal.quest_list.duplicate()
	if sort_alphabetically:
		quests.sort_custom(func(a: Quest, b: Quest) -> bool:
			return QuestUIHelpers.get_title(a).naturalnocasecmp_to(QuestUIHelpers.get_title(b)) < 0)
	for group in group_names:
		_add_quest_group(quests, group)
	if num_groupless > 0:
		_add_quests_in_group(quests, "", selection_container)


func _add_quest_group(quests: Array[Quest], group: String) -> void:
	var foldout: QuestFoldout
	if group_template != null:
		foldout = group_template.instantiate() as QuestFoldout
	else:
		foldout = QuestFoldout.new()
	selection_container.add_child(foldout)
	foldout.assign(tr(group), is_group_expanded(group))
	foldout.header_button.disabled = always_expand_all_groups
	if not always_expand_all_groups:
		foldout.header_pressed.connect(_on_group_pressed.bind(group, foldout))
	_add_quests_in_group(quests, group, foldout.interior)


func _add_quests_in_group(quests: Array[Quest], group: String, container: Node) -> void:
	_add_quests_in_group_filtered(quests, group, container, true)
	_add_quests_in_group_filtered(quests, group, container, false)


func _add_quests_in_group_filtered(quests: Array[Quest], group: String, container: Node, only_active: bool) -> void:
	for quest in quests:
		if not _is_listed(quest):
			continue
		var is_active := quest.get_state() == Quest.State.ACTIVE
		if only_active != is_active or quest.group != group:
			continue
		_add_quest_to_ui(quest, container)


func _add_quest_to_ui(quest: Quest, container: Node) -> void:
	if not show_quests_that_have_no_content and _get_quest_contents(quest).size() <= 1:
		return
	var template := active_quest_name_template if quest.get_state() == Quest.State.ACTIVE \
			else completed_quest_name_template
	var row: QuestNameButton
	if template != null:
		row = template.instantiate() as QuestNameButton
	else:
		row = QuestNameButton.new()
	container.add_child(row)
	row.assign(quest)
	row.selected.connect(select_quest)
	row.tracking_toggled.connect(_on_toggle_tracking)
	if show_details_on_focus:
		row.name_button.mouse_entered.connect(select_quest.bind(quest))
		row.name_button.focus_entered.connect(select_quest.bind(quest))
	if _focused_quest != null:
		if quest == _focused_quest:
			_focus_target = row.track_toggle if _focused_track_toggle and row.track_toggle.visible else row.name_button
	elif (show_first_quest_details_on_open and _just_shown) or quest == selected_quest:
		if _just_toggled_tracking:
			_just_toggled_tracking = false
			_focus_target = row.track_toggle
		else:
			_focus_target = row.name_button


func _find_first_quest_control() -> Control:
	for button in selection_container.find_children("*", "Button", true, false):
		if button is Button and button.is_visible_in_tree() and not button.disabled \
				and not (button is CheckBox) and button.get_parent() is QuestNameButton:
			return button
	return null


func _on_group_pressed(group: String, foldout: QuestFoldout) -> void:
	toggle_group(group)
	foldout.toggle_interior()


func _repaint_selected_quest() -> void:
	if not is_node_ready():
		return
	details.clear()
	if selected_quest != null and journal != null and not journal.quest_list.has(selected_quest):
		selected_quest = null
	track_button.hide()
	abandon_button.hide()
	if selected_quest == null:
		if journal != null:
			details.add_body(tr(no_selection_text) if _find_first_quest_control() != null else tr(no_quests_text), true)
		return
	var contents := _get_quest_contents(selected_quest)
	details.add_contents(contents)
	if QuestUIHelpers.wants_objectives(selected_quest, not contents.is_empty()) \
			and selected_quest.get_state() == Quest.State.ACTIVE:
		details.add_heading(QuestUIHelpers.get_title(selected_quest), 1)
		details.add_objectives(selected_quest)
	if QuestUIHelpers.wants_time_remaining(selected_quest):
		details.add_time_remaining(selected_quest)
	var state := selected_quest.get_state()
	var is_active := state == Quest.State.ACTIVE
	var show_track := show_track_button_in_details and is_active and selected_quest.is_trackable
	var show_abandon := selected_quest.is_abandonable and is_active
	track_button.visible = show_track
	track_button.set_pressed_no_signal(selected_quest.show_in_track_hud)
	abandon_button.visible = show_abandon


func _get_quest_contents(quest: Quest) -> Array[QuestContent]:
	var contents := quest.get_content_list(QuestContent.Category.JOURNAL)
	if contents.is_empty() and show_dialogue_content_if_no_journal_content:
		contents = quest.get_content_list(QuestContent.Category.DIALOGUE)
		if contents.is_empty() and show_offer_content_if_no_journal_or_dialogue_content:
			contents = quest.offer_content_list
	return contents


func _on_details_track_toggled(value: bool) -> void:
	if selected_quest != null:
		_on_toggle_tracking(selected_quest, value)


func _on_toggle_tracking(quest: Quest, value: bool) -> void:
	if quest == null:
		return
	selected_quest = quest
	_just_toggled_tracking = true
	if journal != null and _quest_in_journal(quest):
		journal.set_tracking(quest.id, value)
	else:
		quest.show_in_track_hud = value
	QuestMessages.refresh_uis(quest)
	_schedule_refresh()


func _quest_in_journal(quest: Quest) -> bool:
	return journal != null and journal.quest_list.has(quest)


func _close_abandon_panel() -> void:
	if abandon_panel != null and abandon_panel.visible:
		abandon_panel.hide()
		if abandon_button.visible:
			abandon_button.grab_focus()
