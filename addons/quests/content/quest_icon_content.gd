class_name QuestIconContent
extends QuestContent
## An image with an optional caption and count.

## The image.
@export var image: Texture2D
## Image color.
@export var color := Color.WHITE
## The caption. Can be blank.
@export var caption := ""
## The count to show on the count label. If 0 or 1, the count is not shown.
@export var count := 0


func get_original_text() -> String:
	return caption


func get_editor_name() -> String:
	if not caption.is_empty():
		return "Icon: " + (str(count) + " " if count > 1 else "") + caption
	if image != null:
		return "Icon: " + image.resource_path.get_file().get_basename()
	return "Icon"


func get_images() -> Array[Texture2D]:
	var images: Array[Texture2D] = []
	if image != null:
		images.append(image)
	return images
