@tool
extends RefCounted
## Small helpers shared by the Juice editor tools.


## An icon from the editor theme, or null when this editor version has none by that name.
static func icon(icon_name: StringName) -> Texture2D:
	var theme := EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon(icon_name, &"EditorIcons"):
		return theme.get_icon(icon_name, &"EditorIcons")
	return null


## An icon shipped with the addon, or null when it is not imported yet.
static func addon_icon(file_name: String) -> Texture2D:
	var path := "res://addons/juice/icons/%s.svg" % file_name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


## Gives a button an icon, or the fallback text when there is no icon.
static func set_icon(button: Button, texture: Texture2D, fallback_text: String) -> void:
	if texture != null:
		button.icon = texture
	else:
		button.text = fallback_text


static func format_time(seconds: float) -> String:
	return "%.2f s" % seconds
