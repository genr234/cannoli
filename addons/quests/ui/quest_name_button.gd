class_name QuestNameButton
extends HBoxContainer
## A row in the journal's quest list: the quest icon, a button with the quest
## title, and a toggle that tracks the quest in the HUD. To customize, make a scene
## with this script as its root and assign the exported controls.

## Emitted when the name button is pressed.
signal selected(quest: Quest)
## Emitted when the track toggle changes.
signal tracking_toggled(quest: Quest, value: bool)

## Shows the quest's icon. Built if left unset.
@export var icon_rect: TextureRect
## The title button. Built if left unset.
@export var name_button: Button
## The track toggle. Built if left unset.
@export var track_toggle: CheckBox
## Size of the built-in icon.
@export var icon_size := Vector2(24, 24)

## The quest this row shows.
var quest: Quest


func _ready() -> void:
	_ensure_built()


## Fills the row from [param p_quest].
func assign(p_quest: Quest) -> void:
	_ensure_built()
	quest = p_quest
	if quest == null:
		return
	name = QuestUIHelpers.get_title(quest)
	name_button.text = QuestUIHelpers.get_title(quest)
	icon_rect.texture = quest.icon
	icon_rect.visible = quest.icon != null
	var can_track := quest.get_state() == Quest.State.ACTIVE and quest.is_trackable
	track_toggle.visible = can_track
	track_toggle.set_pressed_no_signal(quest.show_in_track_hud)


func _ensure_built() -> void:
	if icon_rect == null:
		icon_rect = TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.custom_minimum_size = icon_size
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		add_child(icon_rect)
	if name_button == null:
		name_button = Button.new()
		name_button.name = "NameButton"
		name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_button.clip_text = true
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(name_button)
	if track_toggle == null:
		track_toggle = CheckBox.new()
		track_toggle.name = "TrackToggle"
		track_toggle.tooltip_text = tr("Track quest")
		add_child(track_toggle)
	if not name_button.pressed.is_connected(_on_name_pressed):
		name_button.pressed.connect(_on_name_pressed)
		track_toggle.toggled.connect(_on_track_toggled)


func _on_name_pressed() -> void:
	selected.emit(quest)


func _on_track_toggled(value: bool) -> void:
	tracking_toggled.emit(quest, value)
