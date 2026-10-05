class_name QuestVerbCompletion
extends Resource
## How a verb's quest node is completed: by a message, or by a counter reaching a value.

enum Mode { MESSAGE, COUNTER }

## How the verb is completed.
@export var mode := Mode.MESSAGE
## Required message sender.
@export var sender_specifier := QuestMessages.Participant.ANY
## Required message sender ID, or any sender if blank. Can also be {QUESTERID} or {QUESTGIVERID}.
@export var sender_id := ""
## Required message target.
@export var target_specifier := QuestMessages.Participant.ANY
## Required message target ID, or any target if blank. Can also be {QUESTERID} or {QUESTGIVERID}.
@export var target_id := ""
## Required message. In message mode the node completes when it's received.
@export var message := ""
## Required message parameter. May contain {TARGETENTITY} and {DOMAIN}.
@export var parameter := ""
## Counter name. The plural name of the goal entity is prefixed to it.
@export var base_counter_name := ""
@export var initial_value := 0
@export var min_value := 0
@export var max_value := 100
## If the counter value mode is AT_LEAST, the verb requires at least this value.
## If AT_MOST, it requires no more than this value.
@export var required_value := 1
@export var counter_value_mode := QuestCounterCondition.CounterValueMode.AT_LEAST
## How the counter updates its value.
@export var update_mode := QuestCounter.UpdateMode.MESSAGES
## When the update mode is MESSAGES, these messages affect the counter value.
@export var message_event_list: Array[QuestCounterMessageEvent] = []
