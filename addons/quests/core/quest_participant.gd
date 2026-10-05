class_name QuestParticipant
extends RefCounted
## Identifying information about a quest giver, quester or other speaker.

var id: String
var display_name: String
var image: Texture2D
## Words this participant uses for [code]{Word}[/code] tags in quest text, which gives
## each speaker their own dialect. A value may list alternatives separated by
## [code]|[/code]; one is chosen. Empty if the participant has no dialect.
var text_table: Dictionary = {}


func _init(p_id := "", p_display_name := "", p_image: Texture2D = null, p_text_table: Dictionary = {}) -> void:
	id = p_id
	display_name = p_display_name
	image = p_image
	text_table = p_text_table
