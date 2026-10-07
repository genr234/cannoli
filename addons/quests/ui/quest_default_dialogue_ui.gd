@icon("../icons/quest_ui.svg")
class_name QuestDefaultDialogueUI
extends QuestDialogueUI
## The default quest dialogue UI: a panel with the speaker's name and image,
## scrollable quest content, and Back / Close / Accept / Decline buttons.
##
## Expects the nodes of [code]quest_dialogue_ui.tscn[/code] (unique names
## [code]%SpeakerName[/code], [code]%SpeakerImage[/code], [code]%Content[/code],
## [code]%Scroll[/code], [code]%BackButton[/code], [code]%CloseButton[/code],
## [code]%AcceptButton[/code], [code]%DeclineButton[/code]).
## [code]ui_cancel[/code] declines an offer or closes the dialogue.

## Move keyboard/gamepad focus to the first useful button when content changes.
@export var auto_focus := true
## Show the quest's title above its offer, unless the offer already starts with it.
@export var show_title_on_offer := true

## The quest shown by the offer or active-quest views.
var selected_quest: Quest

var _accept_handler := Callable()
var _decline_handler := Callable()
var _back_handler := Callable()

@onready var speaker_name: Label = %SpeakerName
@onready var speaker_image: TextureRect = %SpeakerImage
@onready var content_view: QuestContentView = %Content
@onready var scroll: ScrollContainer = %Scroll
@onready var back_button: Button = %BackButton
@onready var close_button: Button = %CloseButton
@onready var accept_button: Button = %AcceptButton
@onready var decline_button: Button = %DeclineButton


func _ready() -> void:
	back_button.pressed.connect(back)
	close_button.pressed.connect(close)
	accept_button.pressed.connect(accept_quest)
	decline_button.pressed.connect(decline_quest)
	content_view.group_button_clicked.connect(_on_group_button_clicked)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed(&"ui_cancel"):
		return
	if decline_button.visible and not decline_button.disabled:
		decline_quest()
	elif close_button.visible and not close_button.disabled:
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func show_contents(speaker: QuestParticipant, contents: Array[QuestContent]) -> void:
	show()
	_set_contents(speaker, contents)
	_set_control_buttons(true, false, false)
	scroll.scroll_vertical = 0


func show_offer_conditions_unmet(speaker: QuestParticipant, contents: Array[QuestContent], quests: Array[Quest]) -> void:
	for quest in quests:
		if quest != null and not quest.offer_conditions_unmet_content_list.is_empty():
			show_contents(speaker, quest.offer_conditions_unmet_content_list)
			return
	show_contents(speaker, contents)


func show_offer_quest(speaker: QuestParticipant, quest: Quest, accept_handler: Callable, decline_handler: Callable) -> void:
	selected_quest = quest
	_accept_handler = accept_handler
	_decline_handler = decline_handler
	show_contents(speaker, quest.offer_content_list)
	if show_title_on_offer:
		_add_title_heading(quest)
	_set_control_buttons(false, false, true)


func show_active_quest(speaker: QuestParticipant, quest: Quest, _continue_handler: Callable, back_handler: Callable) -> void:
	selected_quest = quest
	_back_handler = back_handler
	var contents := quest.get_content_list(QuestContent.Category.DIALOGUE, speaker)
	show_contents(speaker, contents)
	_set_control_buttons(true, back_handler.is_valid(), false)
	if QuestContentView.contains_group_button(contents):
		_set_control_buttons_interactable(false)


func show_completed_quest(speaker: QuestParticipant, quests: Array[Quest]) -> void:
	if quests == null or quests.is_empty():
		return
	var all_contents: Array[QuestContent] = []
	for quest in quests:
		if quest != null:
			all_contents.append_array(quest.get_content_list(QuestContent.Category.DIALOGUE))
	if all_contents.is_empty():
		return
	show_contents(speaker, all_contents)
	if QuestContentView.contains_group_button(all_contents):
		_set_control_buttons_interactable(false)


func show_quest_list(speaker: QuestParticipant, active_contents: Array[QuestContent], active_quests: Array[Quest],
		offerable_contents: Array[QuestContent], offerable_quests: Array[Quest], select_handler: Callable) -> void:
	var none: Array[QuestContent] = []
	show_contents(speaker, none)
	_set_control_buttons(true, false, false)
	if active_quests != null and not active_quests.is_empty():
		content_view.end_lists()
		add_quest_list(active_contents, active_quests, select_handler)
	if offerable_quests != null and not offerable_quests.is_empty():
		content_view.end_lists()
		add_quest_list(offerable_contents, offerable_quests, select_handler)
	_focus_default()


## Adds [param contents] and then a button for each quest.
func add_quest_list(contents: Array[QuestContent], quests: Array[Quest], select_handler: Callable) -> void:
	content_view.add_contents(contents)
	if quests == null:
		return
	for quest in quests:
		if quest == null:
			continue
		var callback := select_handler.bind(quest) if select_handler.is_valid() else Callable()
		content_view.add_button(quest.icon, 1, QuestUIHelpers.get_title(quest), Color.WHITE, callback)


func close() -> void:
	hide()
	closed.emit()


## Calls the accept handler with the selected quest.
func accept_quest() -> void:
	if _accept_handler.is_valid():
		_accept_handler.call(selected_quest)


## Calls the decline handler with the selected quest.
func decline_quest() -> void:
	if _decline_handler.is_valid():
		_decline_handler.call(selected_quest)


## Calls the back handler with the selected quest.
func back() -> void:
	if _back_handler.is_valid():
		_back_handler.call(selected_quest)


## Sets the back handler; an invalid one hides the back button.
func set_back_handler(handler: Callable) -> void:
	_back_handler = handler
	back_button.visible = handler.is_valid()


func _add_title_heading(quest: Quest) -> void:
	var title := QuestUIHelpers.get_title(quest)
	if title.is_empty():
		return
	var first := quest.offer_content_list[0] if not quest.offer_content_list.is_empty() else null
	if first is QuestHeadingContent and first.get_text() == title:
		return
	var heading := content_view.add_heading(title, 2)
	content_view.move_child(heading, 0)


func _set_contents(speaker: QuestParticipant, contents: Array[QuestContent]) -> void:
	speaker_name.text = speaker.display_name if speaker != null else ""
	speaker_name.visible = not speaker_name.text.is_empty()
	speaker_image.texture = speaker.image if speaker != null else null
	speaker_image.visible = speaker_image.texture != null
	content_view.set_contents(contents)


func _set_control_buttons(enable_close: bool, enable_back: bool, enable_accept_decline: bool) -> void:
	_set_control_buttons_interactable(true)
	close_button.visible = enable_close
	back_button.visible = enable_back
	accept_button.visible = enable_accept_decline
	decline_button.visible = enable_accept_decline
	if auto_focus:
		_focus_default.call_deferred()


func _set_control_buttons_interactable(value: bool) -> void:
	close_button.disabled = not value
	back_button.disabled = not value
	accept_button.disabled = not value
	decline_button.disabled = not value


func _focus_default() -> void:
	if not is_visible_in_tree():
		return
	var target: Control
	if accept_button.visible:
		target = decline_button
	else:
		for button in content_view.get_buttons():
			if not button.disabled and button.is_visible_in_tree():
				target = button
				break
		if target == null:
			target = back_button if back_button.visible else close_button
	if target != null and target.is_visible_in_tree():
		target.grab_focus()


func _on_group_button_clicked(_group: int) -> void:
	_set_control_buttons_interactable(true)
