@icon("../icons/quest_hud.svg")
class_name QuestDefaultHUD
extends QuestHUD
## The default quest HUD: lists tracked quests' HUD content in a corner of the
## screen. When a tracked quest has no HUD content and
## [member Quest.auto_objectives] is on, it shows the quest title and objective
## lines ("Wolves slain 3/5"); quests with a time limit also show the time left.
##
## Expects a [QuestContentView] named [code]%Content[/code]. The HUD ignores mouse input so it never blocks the game.

## Show the HUD at all. Changed by [method open] and [method close].
@export var show_hud := true
## Organize quests under their group name.
@export var use_groups := false
@export var show_active_quests := true
@export var show_successful_quests := false
@export var show_failed_quests := false
## If no quests are being tracked, hide the HUD.
@export var hide_if_no_tracked_quests := false
## Optional template for group headings (a [Label] or a scene with [code]assign_text[/code]).
@export var group_template: PackedScene
## When no list was opened, bind to the player's journal on startup.
@export var auto_bind_player_journal := true

## The list being shown.
var quest_list: QuestList

var _expanded_groups: Array[String] = []
var _refresh_pending := false
var _bound_list: QuestList

@onready var content_view: QuestContentView = %Content
@onready var panel: Control = get_node_or_null("%Panel") as Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for message in [QuestMessages.REFRESH_UIS, QuestMessages.QUEST_STATE_CHANGED,
			QuestMessages.QUEST_COUNTER_CHANGED, QuestMessages.QUEST_TRACK_TOGGLE_CHANGED,
			QuestMessages.TIMER_TICK]:
		QuestMessages.add_listener(self, message, "", _on_message)
	if auto_bind_player_journal:
		_try_bind_player_journal.call_deferred()


func _exit_tree() -> void:
	QuestMessages.remove_listener(self)


func open(list: QuestList) -> void:
	show_hud = true
	if _should_be_visible_for(list):
		show()
		repaint(list)


func close() -> void:
	show_hud = false
	hide()


func toggle(list: QuestList) -> void:
	if visible:
		close()
	else:
		open(list)


## Sets [member show_hud] and shows or hides the HUD to match.
func set_visibility(list: QuestList, value: bool) -> void:
	show_hud = value
	if (visible and not show_hud) or (not visible and show_hud):
		toggle(list)


func repaint(list: QuestList) -> void:
	_bind(list)
	if _should_be_visible():
		_make_visible()
		_schedule_refresh()
	else:
		_make_invisible()


func is_group_expanded(group: String) -> bool:
	return _expanded_groups.has(group)


func toggle_group(group: String) -> void:
	if is_group_expanded(group):
		_expanded_groups.erase(group)
	else:
		_expanded_groups.append(group)


## Redraws the HUD immediately instead of at the end of the frame.
func refresh_now() -> void:
	_refresh_pending = false
	if quest_list == null:
		return
	content_view.clear()
	if use_groups:
		_refresh_by_group()
	else:
		_add_quests("", true, false)
	if panel != null:
		panel.visible = content_view.get_child_count() > 0


func _bind(list: QuestList) -> void:
	quest_list = list
	if _bound_list == list:
		return
	if is_instance_valid(_bound_list):
		_bound_list.quest_added.disconnect(_on_list_changed)
		_bound_list.quest_removed.disconnect(_on_list_changed)
		_bound_list.quest_state_changed.disconnect(_on_list_changed)
	_bound_list = list
	if list != null:
		list.quest_added.connect(_on_list_changed)
		list.quest_removed.connect(_on_list_changed)
		list.quest_state_changed.connect(_on_list_changed)


func _on_list_changed(_arg: Variant = null) -> void:
	_schedule_refresh()


func _schedule_refresh() -> void:
	if _refresh_pending:
		return
	_refresh_pending = true
	_refresh_deferred.call_deferred()


func _refresh_deferred() -> void:
	if _refresh_pending:
		refresh_now()


func _on_message(args: QuestMessageArgs) -> void:
	if quest_list == null:
		if args.message == QuestMessages.TIMER_TICK:
			_try_bind_player_journal()
		return
	if args.message == QuestMessages.TIMER_TICK and not _has_time_limited_quest():
		return
	if args.message == QuestMessages.QUEST_STATE_CHANGED or args.message == QuestMessages.REFRESH_UIS:
		repaint(quest_list)
	elif show_hud and _should_be_visible():
		_make_visible()
		_schedule_refresh()


func _try_bind_player_journal() -> void:
	if quest_list != null or not auto_bind_player_journal:
		return
	var journal := Quests.get_journal()
	if journal != null:
		repaint(journal)


func _has_time_limited_quest() -> bool:
	for quest in quest_list.quest_list:
		if quest != null and QuestUIHelpers.wants_time_remaining(quest) and quest.show_in_track_hud:
			return true
	return false


func _is_shown(quest: Quest) -> bool:
	return QuestUIHelpers.is_hud_visible_quest(quest, show_active_quests, show_successful_quests, show_failed_quests)


func _should_be_visible() -> bool:
	return _should_be_visible_for(quest_list)


func _should_be_visible_for(list: QuestList) -> bool:
	if not show_hud or list == null:
		return false
	if not hide_if_no_tracked_quests:
		return true
	for quest in list.quest_list:
		if _is_shown(quest):
			return true
	return false


func _make_invisible() -> void:
	modulate.a = 0.0
	_refresh_pending = false


func _make_visible() -> void:
	modulate.a = 1.0
	if not visible and show_hud:
		show()


func _refresh_by_group() -> void:
	var groups: Array[String] = []
	for quest in quest_list.quest_list:
		if quest == null or quest.group.is_empty() or groups.has(quest.group):
			continue
		if _is_shown(quest):
			groups.append(quest.group)
	groups.sort_custom(func(a: String, b: String) -> bool: return a.naturalnocasecmp_to(b) < 0)
	for group in groups:
		_add_group_heading(group)
		_add_quests(group, false, false)
	_add_quests("", false, true)


func _add_group_heading(group: String) -> void:
	if group_template != null:
		var control := group_template.instantiate() as Control
		if control.has_method("assign_text"):
			control.call("assign_text", tr(group))
		elif control is Label:
			(control as Label).text = tr(group)
		content_view.add_child(control)
		content_view.end_lists()
	else:
		var label := content_view.add_heading(tr(group), 2)
		label.name = "GroupHeading"


func _add_quests(group: String, show_all: bool, show_ungrouped: bool) -> void:
	for quest in quest_list.quest_list:
		if quest == null:
			continue
		var in_group := show_all or (show_ungrouped and quest.group.is_empty()) or quest.group == group
		if not in_group or not _is_shown(quest):
			continue
		_add_quest(quest)


func _add_quest(quest: Quest) -> void:
	var has_content := false
	for entry: Dictionary in QuestUIHelpers.get_hud_content_groups(quest):
		var contents: Array[QuestContent] = []
		contents.assign(entry["contents"])
		if not contents.is_empty():
			has_content = true
		content_view.add_contents(contents, not entry["active"])
	if QuestUIHelpers.wants_objectives(quest, has_content):
		content_view.add_heading(QuestUIHelpers.get_title(quest), 1, quest.get_state() != Quest.State.ACTIVE)
		content_view.add_objectives(quest)
	if QuestUIHelpers.wants_time_remaining(quest):
		content_view.add_time_remaining(quest)
