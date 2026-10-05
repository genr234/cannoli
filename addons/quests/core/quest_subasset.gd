class_name QuestSubasset
extends Resource
## Base class for the pieces a quest is made of: conditions, actions and
## content. Subassets are cloned together with their quest. The runtime
## references are set by [method Quest.initialize].

## The quest this subasset belongs to. Runtime only.
var quest: Quest:
	get:
		return _quest_ref.get_ref() as Quest if _quest_ref != null else null
	set(value):
		_quest_ref = weakref(value) if value != null else null
## The node this subasset belongs to, or null if it is on the quest itself. Runtime only.
var quest_node: QuestNode:
	get:
		return _node_ref.get_ref() as QuestNode if _node_ref != null else null
	set(value):
		_node_ref = weakref(value) if value != null else null

var _quest_ref: WeakRef
var _node_ref: WeakRef


## Virtual. Called when the quest wires its runtime references. Call super.
func set_runtime_references(p_quest: Quest, p_node: QuestNode) -> void:
	quest = p_quest
	quest_node = p_node
	add_tags_to_dictionary()


## Virtual. Add the tags used by this subasset's text to the quest's tag dictionary.
func add_tags_to_dictionary() -> void:
	pass


## Virtual. Shown in editor lists.
func get_editor_name() -> String:
	return get_type_name()


## Virtual. Images used by this subasset.
func get_images() -> Array[Texture2D]:
	return []


## Virtual. Audio used by this subasset.
func get_audio() -> Array[AudioStream]:
	return []


## The global class name of this subasset's script.
func get_type_name() -> String:
	var script := get_script() as Script
	return String(script.get_global_name()) if script != null else get_class()


## Adds the tags found in [param text] to the quest's tag dictionary.
func add_text_tags(text: String) -> void:
	if quest != null:
		QuestTags.add_tags_to_dictionary(quest.tag_dictionary, text)


## Replaces tags in [param text] using this subasset's quest.
func replace_tags(text: String) -> String:
	return QuestTags.replace_tags(text, quest)
