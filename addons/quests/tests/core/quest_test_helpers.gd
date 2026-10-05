class_name QuestTestHelpers
extends RefCounted
## Builders for the quests used in core tests.


## A quest with the start node linked to the given nodes, in order: start -> a -> b -> ...
static func chain(quest_id: String, nodes: Array[QuestNode]) -> Quest:
	var quest := Quest.create(quest_id)
	var previous := quest.get_start_node()
	for node in nodes:
		quest.node_list.append(node)
		previous.children = PackedStringArray([node.id])
		previous = node
	return quest


static func node(node_id: String, type := QuestNode.Type.PASSTHROUGH) -> QuestNode:
	return QuestNode.create(node_id, node_id, type)


## A condition node with the given number of test conditions.
static func condition_node(node_id: String, count := 1, mode := QuestConditionSet.Mode.ALL) -> QuestNode:
	var result := QuestNode.create(node_id, node_id, QuestNode.Type.CONDITION)
	result.condition_set.condition_count_mode = mode
	for i in count:
		result.condition_set.condition_list.append(QuestTestCondition.new())
	return result


## start -> task (condition) -> done (success). Returns the quest asset.
static func simple_quest(quest_id: String) -> Quest:
	return chain(quest_id, [condition_node("task"), node("done", QuestNode.Type.SUCCESS)])


static func test_condition(quest: Quest, node_id: String, index := 0) -> QuestTestCondition:
	return quest.get_node(node_id).condition_set.condition_list[index] as QuestTestCondition


## A quest with a start node and `count` parallel condition nodes, each linked to the start node.
static func parallel_quest(quest_id: String, node_ids: Array[String]) -> Quest:
	var quest := Quest.create(quest_id)
	var children := PackedStringArray()
	for node_id in node_ids:
		quest.node_list.append(condition_node(node_id))
		children.append(node_id)
	quest.get_start_node().children = children
	return quest


static func counter_quest(quest_id: String, counter_name: String, max_value := 10) -> Quest:
	var quest := simple_quest(quest_id)
	quest.counter_list.append(QuestCounter.create(counter_name, 0, 0, max_value))
	return quest


## Adds a journal with the given id to the test's root.
static func make_journal(test: QuestsTest, journal_id := "player") -> QuestJournal:
	var journal := QuestJournal.new()
	journal.id = journal_id
	journal.name = "Journal_" + journal_id
	return test.add_node(journal) as QuestJournal


## Adds a quest giver with the given id and quest assets to the test's root.
static func make_giver(test: QuestsTest, giver_id: String, assets: Array[Quest]) -> QuestGiver:
	var giver := QuestGiver.new()
	giver.id = giver_id
	giver.name = "Giver_" + giver_id
	giver.quests = assets
	return test.add_node(giver) as QuestGiver
