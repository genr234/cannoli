class_name QuestXPRewardSystem
extends QuestRewardSystem
## Grants XP without using up reward points. On success the quest sends the
## message "Add XP" to the quester, with the amount as its parameter and value.


func determine_reward(points: int, quest: Quest, entity_type: QuestEntityType = null) -> int:
	var xp := int(points * entity_type.get_reward_multiplier(QuestRewardMultiplier.Category.XP)) if entity_type != null else points
	var body_text := QuestBodyContent.new()
	body_text.text = "%d XP" % xp
	quest.offer_content_list.append(body_text)
	var xp_action := QuestMessageAction.new()
	xp_action.sender_id = QuestTags.QUESTGIVERID
	xp_action.target_id = QuestTags.QUESTERID
	xp_action.message = "Add XP"
	xp_action.parameter = str(xp)
	xp_action.value = QuestMessageValue.from_int(xp)
	QuestStateInfo.validate_list(quest.state_info_list, Quest.State.size())
	quest.state_info_list[Quest.State.SUCCESSFUL].action_list.append(xp_action)
	return points
