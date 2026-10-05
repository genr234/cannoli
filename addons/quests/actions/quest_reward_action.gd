class_name QuestRewardAction
extends QuestAction
## Gives a reward: sends a "Quest Reward" message that your game listens for
## (parameter = reward id, value = amount) and optionally adds to a counter.

const REWARD_MESSAGE := "Quest Reward"

## Reward id sent as the message parameter, such as "gold" or "xp". Can contain tags.
@export var reward_id := ""
## Amount of the reward, sent as the message value.
@export var amount := 0
## Also add the amount to this counter of the quest. Leave blank to skip.
@export var counter_name := ""
## Who receives the reward. Blank uses the quester.
@export var recipient_id := ""


func get_editor_name() -> String:
	if reward_id.is_empty():
		return "Reward"
	return "Reward: %d %s" % [amount, reward_id]


func execute() -> void:
	if not counter_name.is_empty() and quest != null:
		var counter := quest.get_counter(counter_name)
		if counter != null:
			counter.set_value(counter.current_value + amount)
		else:
			push_warning("Quests: QuestRewardAction can't find counter '%s'." % counter_name)
	var recipient := QuestTags.replace_tags(recipient_id if not recipient_id.is_empty() else QuestTags.QUESTERID, quest)
	var sender := quest.quest_giver_id if quest != null else ""
	Quests.send_message(REWARD_MESSAGE, QuestTags.replace_tags(reward_id, quest), amount, sender, recipient)
