class_name QuestFoldout
extends VBoxContainer
## A header button that expands and collapses an interior panel; used for quest
## groups. To customize, make a scene with this script as its root and assign
## [member header_button] and [member interior].

## Emitted when the header is pressed.
signal header_pressed()

## The header button. Built if left unset.
@export var header_button: Button
## The container that holds the foldout's content. Built if left unset.
@export var interior: Container
## Text drawn before the group name while expanded and collapsed.
@export var expanded_prefix := "- "
@export var collapsed_prefix := "+ "

var _title := ""


func _ready() -> void:
	_ensure_built()


## Sets the group name and expanded state.
func assign(title: String, expanded: bool) -> void:
	_ensure_built()
	_title = title
	name = title
	interior.visible = expanded
	_update_header()


## Shows or hides the interior.
func toggle_interior() -> void:
	_ensure_built()
	interior.visible = not interior.visible
	_update_header()


func is_expanded() -> bool:
	return interior != null and interior.visible


func _ensure_built() -> void:
	if header_button == null:
		header_button = Button.new()
		header_button.name = "Header"
		header_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		header_button.theme_type_variation = &"QuestFoldoutHeader"
		add_child(header_button)
		move_child(header_button, 0)
	if interior == null:
		var margin := MarginContainer.new()
		margin.name = "InteriorMargin"
		margin.add_theme_constant_override("margin_left", 16)
		add_child(margin)
		var box := VBoxContainer.new()
		box.name = "Interior"
		margin.add_child(box)
		interior = box
	if not header_button.pressed.is_connected(_on_header_pressed):
		header_button.pressed.connect(_on_header_pressed)


func _on_header_pressed() -> void:
	header_pressed.emit()


func _update_header() -> void:
	header_button.text = (expanded_prefix if interior.visible else collapsed_prefix) + _title
	var parent := interior.get_parent()
	if parent is MarginContainer:
		parent.visible = interior.visible
