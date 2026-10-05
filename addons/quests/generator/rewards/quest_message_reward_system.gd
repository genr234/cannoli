class_name QuestMessageRewardSystem
extends QuestRewardSystem
## Grants a reward by sending a message with a count when the quest succeeds,
## such as "Get" with parameter "Coin" and the number of coins as its value.
##
## The message is sent by the quest giver to [member target] (the quester by
## default), with the amount as an integer value, like [QuestRewardAction],
## which sends [constant QuestRewardAction.REWARD_MESSAGE] with the reward id as
## its parameter and the amount as its value. This system keeps the original
## defaults ("Get" and "Coin", in the manual's notation "Get:Coin") so existing
## listeners keep working. To send the same message as [QuestRewardAction], call
## [method use_reward_message_format].

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


## Makes this system send the same message as [QuestRewardAction]: the message
## [constant QuestRewardAction.REWARD_MESSAGE] with [param reward_id] as the parameter.
func use_reward_message_format(reward_id: String) -> void:
	message = QuestRewardAction.REWARD_MESSAGE
	parameter = reward_id
