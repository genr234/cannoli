@icon("../icons/quest_ui.svg")
class_name QuestDefaultAlertUI
extends QuestAlertUI
## The default quest alert UI: shows alerts in a stack, each for a duration based
## on its text length (at least [member min_display_duration]), optionally queueing
## new alerts while one is showing.
##
## Expects a [VBoxContainer] named [code]%Content[/code]. Each alert is a
## [QuestContentView]; alerts with several contents (or any, if
## [member always_use_container]) sit in a panel.

## Emitted when an alert starts showing.
signal alert_shown()

## Optional scene whose root is a [QuestContentView], used for each alert.
@export var content_view_template: PackedScene
## Optional container scene for alerts shown in a panel. Its root, or its
## unique-named [code]%Items[/code] child, receives the alert's content view.
@export var alert_container_template: PackedScene
## Use the container even for single-element content such as a single string.
@export var always_use_container := false
@export_group("Duration")
## Queue new alerts if an alert is currently showing. If your alert UI scrolls
## alerts, leave this off.
@export var queue_alerts := false
## Minimum duration in seconds to show alerts.
@export var min_display_duration := 5.0
## Duration to show alerts in characters per second.
@export var chars_per_sec_duration := 50
## When hiding after the last alert is done, leave its content visible during hide.
@export var leave_last_content_visible_during_hide := false

var _instances: Array[Control] = []
var _queue: Array[Dictionary] = []
var _despawn_running := false

@onready var content_container: VBoxContainer = %Content


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Number of alerts currently on screen.
func get_alert_count() -> int:
	return _instances.size()


## Number of alerts waiting to be shown.
func get_queued_count() -> int:
	return _queue.size()


func show_alert_contents(quest_id: String, contents: Array[QuestContent]) -> void:
	if contents == null or contents.is_empty():
		return
	if not visible:
		_show_ui()
	if queue_alerts and _despawn_running:
		_queue.append({"quest_id": quest_id, "contents": contents, "message": ""})
		return
	var instance: Control
	var view := _make_view()
	if contents.size() == 1 and not always_use_container:
		view.set_contents(contents)
		instance = view
	else:
		view.set_contents(contents)
		instance = _wrap_in_container(view)
	content_container.add_child(instance)
	_instances.append(instance)
	_timed_despawn(instance, get_display_duration(contents))
	alert_shown.emit()


func show_alert(message: String) -> void:
	if message.is_empty():
		return
	if not visible:
		_show_ui()
	if queue_alerts and _despawn_running:
		_queue.append({"quest_id": "", "contents": null, "message": message})
		return
	var view := _make_view()
	view.add_body(message)
	var instance: Control = _wrap_in_container(view) if always_use_container else view
	content_container.add_child(instance)
	_instances.append(instance)
	_timed_despawn(instance, get_display_duration_for_text(message))
	alert_shown.emit()


## Seconds an alert with [param contents] stays on screen.
func get_display_duration(contents: Array[QuestContent]) -> float:
	var duration := min_display_duration
	if contents != null:
		for content in contents:
			duration = maxf(duration, _get_content_duration(content))
	return duration


## Seconds an alert with [param text] stays on screen.
func get_display_duration_for_text(text: String) -> float:
	return maxf(min_display_duration, 0.0 if text.is_empty() else float(text.length()) / chars_per_sec_duration)


func _get_content_duration(content: QuestContent) -> float:
	if content is QuestHeadingContent or content is QuestBodyContent or content is QuestIconContent:
		return get_display_duration_for_text(content.get_text())
	return min_display_duration


func _show_ui() -> void:
	_clear_instances()
	show()


func _clear_instances() -> void:
	for instance in _instances:
		if is_instance_valid(instance):
			instance.get_parent().remove_child(instance)
			instance.free()
	_instances.clear()


func _make_view() -> QuestContentView:
	if content_view_template != null:
		var view := content_view_template.instantiate() as QuestContentView
		if view != null:
			return view
	var default_view := QuestContentView.new()
	default_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return default_view


func _wrap_in_container(view: QuestContentView) -> Control:
	var container: Control
	if alert_container_template != null:
		container = alert_container_template.instantiate() as Control
	else:
		container = PanelContainer.new()
		container.name = "AlertContainer"
	var items := container.get_node_or_null("%Items")
	(items if items != null else container).add_child(view)
	return container


func _timed_despawn(instance: Control, duration: float) -> void:
	_despawn_running = true
	await get_tree().create_timer(duration, true).timeout
	if is_instance_valid(instance):
		if leave_last_content_visible_during_hide and _instances.size() <= 1 and _queue.is_empty():
			hide()
		else:
			_instances.erase(instance)
			instance.get_parent().remove_child(instance)
			instance.free()
			if _instances.is_empty() and _queue.is_empty():
				hide()
	_despawn_running = false
	if not _queue.is_empty():
		var next: Dictionary = _queue.pop_front()
		if str(next["message"]).is_empty():
			var contents: Array[QuestContent] = []
			contents.assign(next["contents"])
			show_alert_contents(next["quest_id"], contents)
		else:
			show_alert(next["message"])
