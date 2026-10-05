@icon("../icons/quest_ui.svg")
class_name QuestUIRoot
extends CanvasLayer
## Drop-in container for the default quest UIs: dialogue, journal, HUD and alerts.
## Add [code]quest_ui.tscn[/code] to your game. On startup it fills any UI slot the
## [QuestManager] leaves empty, and registers the [code]quests_toggle_journal[/code]
## input action (J, or the gamepad back button) if the project lacks it.

## Fill the manager's empty UI slots with these UIs.
@export var register_with_manager := true
## Toggle the player's journal when the [code]quests_toggle_journal[/code] action is pressed.
@export var handle_toggle_journal_action := true
## Open the HUD for the player's journal automatically.
@export var show_hud_on_start := true
## Show [constant QuestMessages.QUEST_ALERT] messages in the alert UI by adding a
## [QuestAlertDisplayer]. Turn off if something else forwards alerts.
@export var forward_alerts := true

@onready var dialogue_ui: QuestDefaultDialogueUI = %DialogueUI
@onready var journal_ui: QuestDefaultJournalUI = %JournalUI
@onready var hud: QuestDefaultHUD = %HUD
@onready var alert_ui: QuestDefaultAlertUI = %AlertUI


func _ready() -> void:
	QuestUIHelpers.ensure_input_actions()
	hud.auto_bind_player_journal = show_hud_on_start
	dialogue_ui.hide()
	journal_ui.hide()
	if forward_alerts:
		var displayer := QuestAlertDisplayer.new()
		displayer.name = "AlertDisplayer"
		displayer.alert_ui = alert_ui
		add_child(displayer)
	if register_with_manager:
		_register.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not handle_toggle_journal_action or not event.is_action_pressed(QuestUIHelpers.TOGGLE_JOURNAL_ACTION):
		return
	var journal := Quests.get_journal()
	if journal != null:
		journal.toggle_journal_ui()
		get_viewport().set_input_as_handled()


func _register() -> void:
	var manager := Quests.get_manager()
	if manager == null:
		return
	if manager.dialogue_ui == null:
		manager.dialogue_ui = dialogue_ui
	if manager.journal_ui == null:
		manager.journal_ui = journal_ui
	if manager.alert_ui == null:
		manager.alert_ui = alert_ui
	if manager.hud == null:
		manager.hud = hud
