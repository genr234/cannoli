class_name QuestTags
extends RefCounted
## Text tags, such as {QUESTGIVER} or {#wolves}, that quest text can contain.
##
## [codeblock]
## {QUEST} {QUESTID}                quest title and id
## {QUESTGIVER} {QUESTER} ...       values from the quest's tag dictionary
## {#counter}                       current value of a counter
## {<#counter} {>#counter}          minimum / maximum value of a counter
## {:counter}                       counter value as a time, such as 01:30
## {#quest:counter}                 counter in another quest
## {TIMELIMIT}                      time left before the quest fails, as a time
## {Word}                           anything else is translated with tr()
## [/codeblock]

const TAG_PREFIX := "{"
const COUNTER_VALUE_TAG_PREFIX := "{#"
const COUNTER_MIN_VALUE_TAG_PREFIX := "{<#"
const COUNTER_MAX_VALUE_TAG_PREFIX := "{>#"
const COUNTER_TIME_VALUE_TAG_PREFIX := "{:"
const COUNTER_TAG_QUEST_NAME_SEPARATOR := ":"

const QUESTID := "{QUESTID}"
const QUEST := "{QUEST}"
const QUESTGIVER := "{QUESTGIVER}"
const QUESTGIVERID := "{QUESTGIVERID}"
const QUESTER := "{QUESTER}"
const QUESTERID := "{QUESTERID}"
const GREETER := "{GREETER}"
const GREETERID := "{GREETERID}"
const TIMELIMIT := "{TIMELIMIT}"
# Generator tags:
const DOMAIN := "{DOMAIN}"
const ACTION := "{ACTION}"
const TARGETDESCRIPTOR := "{TARGETDESCRIPTOR}"
const TARGET := "{TARGET}"
const TARGETS := "{TARGETS}"
const COUNTERGOAL := "{COUNTERGOAL}"
const REWARD := "{REWARD}"

enum _CounterTagType { CURRENT, MIN, MAX, AS_TIME }

static var _regex: RegEx


static func _get_regex() -> RegEx:
	if _regex == null:
		_regex = RegEx.new()
		_regex.compile("\\{[^\\}]+\\}")
	return _regex


static func contains_any_tag(text: String) -> bool:
	return text.contains(TAG_PREFIX)


static func is_dynamic_tag(tag: String) -> bool:
	return tag.begins_with(COUNTER_VALUE_TAG_PREFIX) or tag.begins_with(COUNTER_MIN_VALUE_TAG_PREFIX) \
			or tag.begins_with(COUNTER_MAX_VALUE_TAG_PREFIX) or tag.begins_with(COUNTER_TIME_VALUE_TAG_PREFIX) \
			or tag == TIMELIMIT


static func is_id_tag(tag: String) -> bool:
	return tag in [QUESTERID, QUESTER, QUESTGIVERID, QUESTGIVER, DOMAIN, ACTION, TARGETDESCRIPTOR, TARGET,
			TARGETS, COUNTERGOAL, REWARD]


## The id a message participant must have, given a specifier. ANY returns an
## empty string (any id), QUESTER and QUEST_GIVER return tags that
## [method replace_tags] resolves for the quest, and OTHER returns [param id].
static func get_id_by_specifier(specifier: QuestMessages.Participant, id: String) -> String:
	match specifier:
		QuestMessages.Participant.ANY:
			return ""
		QuestMessages.Participant.QUESTER:
			return QUESTERID
		QuestMessages.Participant.QUEST_GIVER:
			return QUESTGIVERID
	return id


## Adds the static tags found in [param text] to [param tag_dictionary] with
## empty values, so they can be filled in later. Dynamic tags are skipped.
static func add_tags_to_dictionary(tag_dictionary: Dictionary, text: String) -> void:
	if tag_dictionary == null or not contains_any_tag(text):
		return
	for m in _get_regex().search_all(text):
		var tag := m.get_string()
		if is_dynamic_tag(tag) or tag_dictionary.has(tag):
			continue
		tag_dictionary[tag] = ""


## Translates [param text] and replaces the tags in it using [param quest].
static func replace_tags(text: String, quest: Quest) -> String:
	if text.is_empty():
		return text
	var source := TranslationServer.translate(text)
	if not contains_any_tag(source):
		return source
	var quest_tags: Dictionary = quest.tag_dictionary if quest != null else {}
	var node_tags := _get_active_node_tags(quest)
	var matches := _get_regex().search_all(source)
	var result := ""
	var position := 0
	for m in matches:
		result += source.substr(position, m.get_start() - position)
		result += _replace_tag(m.get_string(), quest, quest_tags, node_tags)
		position = m.get_end()
	return result + source.substr(position)


## The tag dictionary of the latest active node, or an empty one.
static func _get_active_node_tags(quest: Quest) -> Dictionary:
	if quest == null or quest.get_state() != Quest.State.ACTIVE:
		return {}
	var result := {}
	for node in quest.node_list:
		if node != null and node.get_state() == QuestNode.State.ACTIVE:
			result = node.tag_dictionary
	return result


static func _replace_tag(tag: String, quest: Quest, quest_tags: Dictionary, node_tags: Dictionary) -> String:
	if tag == QUEST:
		return quest.title if quest != null else tag
	if tag == QUESTID:
		return quest.id if quest != null else tag
	if tag == TIMELIMIT:
		return seconds_to_time_string(ceili(quest.time_remaining)) if quest != null else tag
	if tag.begins_with(COUNTER_MIN_VALUE_TAG_PREFIX):
		return _replace_counter_tag(tag, quest, _CounterTagType.MIN)
	if tag.begins_with(COUNTER_MAX_VALUE_TAG_PREFIX):
		return _replace_counter_tag(tag, quest, _CounterTagType.MAX)
	if tag.begins_with(COUNTER_VALUE_TAG_PREFIX):
		return _replace_counter_tag(tag, quest, _CounterTagType.CURRENT)
	if tag.begins_with(COUNTER_TIME_VALUE_TAG_PREFIX):
		return _replace_counter_tag(tag, quest, _CounterTagType.AS_TIME)
	if tag == QUESTGIVERID and quest != null and not quest.quest_giver_id.is_empty() and not quest_tags.has(tag):
		return quest.quest_giver_id
	if node_tags.has(tag):
		return str(node_tags[tag])
	if quest_tags.has(tag):
		return str(quest_tags[tag])
	var field_name := tag.substr(1, tag.length() - 2).strip_edges()
	return TranslationServer.translate(field_name)


static func _replace_counter_tag(tag: String, quest: Quest, tag_type: _CounterTagType) -> String:
	if quest == null:
		return tag
	var prefix_length := 3 if tag_type == _CounterTagType.MIN or tag_type == _CounterTagType.MAX else 2
	var counter_name := tag.substr(prefix_length, tag.length() - prefix_length - 1).strip_edges()
	var counter := quest.get_counter(counter_name)
	if counter != null:
		return _get_counter_tag_value(counter, tag_type)
	var index := counter_name.find(COUNTER_TAG_QUEST_NAME_SEPARATOR)
	if index > 0:
		var other := Quests.get_quest_instance(counter_name.substr(0, index))
		counter = other.get_counter(counter_name.substr(index + 1)) if other != null else null
		if counter != null:
			return _get_counter_tag_value(counter, tag_type)
	return tag


static func _get_counter_tag_value(counter: QuestCounter, tag_type: _CounterTagType) -> String:
	match tag_type:
		_CounterTagType.MIN:
			return str(counter.min_value)
		_CounterTagType.MAX:
			return str(counter.max_value)
		_CounterTagType.AS_TIME:
			return seconds_to_time_string(counter.current_value)
	return str(counter.current_value)


## Formats seconds as "45", "01:30", "01:02:03" or "2d, 01:02:03".
static func seconds_to_time_string(seconds: int) -> String:
	if seconds < 60:
		return str(maxi(seconds, 0))
	var days := seconds / 86400
	var hours := (seconds % 86400) / 3600
	var minutes := (seconds % 3600) / 60
	var secs := seconds % 60
	if days > 0:
		return "%dd, %02d:%02d:%02d" % [days, hours, minutes, secs]
	if hours > 0:
		return "%02d:%02d:%02d" % [hours, minutes, secs]
	return "%02d:%02d" % [minutes, secs]
