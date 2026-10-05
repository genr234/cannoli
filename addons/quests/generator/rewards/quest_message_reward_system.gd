class_name QuestMessageRewardSystem
extends QuestRewardSystem
## Grants a reward by sending a message with a count when the quest succeeds,
## such as "Get" with parameter "Coin" and the number of coins as its value.

## Use up reward points when determining the reward.
@export var consume_points := true
## How the number passed with the message scales with the points.
@export var points_curve: Curve = QuestCurves.linear([Vector2(1, 1), Vector2(100, 100)])
## What is being given, shown in the offer text as "[amount] [thing]". Leave blank for no text.
@export var thing := "Coins"
@export var target := QuestTags.QUESTERID
@export var message := "Get"
@export var parameter := "Coin"


func determine_reward(points: int, quest: Quest, _entity_type: QuestEntityType = null) -> int:
	var amount := int(QuestCurves.evaluate(points_curve, points))
	if not thing.is_empty():
		var body_text := QuestBodyContent.new()
		body_text.text = "%d %s" % [amount, thing]
		quest.offer_content_list.append(body_text)
	var message_action := QuestMessageAction.new()
	message_action.sender_id = QuestTags.QUESTGIVERID
	message_action.target_id = target
	message_action.message = message
	message_action.parameter = parameter
	message_action.value = QuestMessageValue.from_int(amount)
	QuestStateInfo.validate_list(quest.state_info_list, Quest.State.size())
	quest.state_info_list[Quest.State.SUCCESSFUL].action_list.append(message_action)
	return (points - amount) if consume_points else points
