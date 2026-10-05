class_name QuestAlertDisplayer
extends Node
## Listens for [constant QuestMessages.QUEST_ALERT] messages and shows them in an
## alert UI. Add one if nothing else forwards alerts to your alert UI.

## The alert UI to use. If unassigned, uses the [QuestManager]'s alert UI.
@export var alert_ui: QuestAlertUI


func _enter_tree() -> void:
	QuestMessages.add_listener(self, QuestMessages.QUEST_ALERT, "", _on_alert)


func _exit_tree() -> void:
	QuestMessages.remove_listener(self)


# The last alert shown and the UI that showed it, so that two displayers that
# share a UI never show the same alert twice.
static var _last_args: WeakRef
static var _last_ui: WeakRef


func _on_alert(args: QuestMessageArgs) -> void:
	var ui := alert_ui
	if ui == null and QuestManager.instance != null:
		ui = QuestManager.instance.alert_ui
	if ui == null:
		return
	if _last_args != null and _last_args.get_ref() == args and _last_ui.get_ref() == ui:
		return
	_last_args = weakref(args)
	_last_ui = weakref(ui)
	var contents: Array[QuestContent] = []
	if not args.values.is_empty() and args.values[0] is Array:
		contents.assign(args.values[0])
	ui.show_alert_contents(args.parameter, contents)
