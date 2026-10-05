class_name PartsTestUtil
extends RefCounted
## Helpers shared by the parts tests. Doesn't reference the Relationships
## addon by name, so the tests also parse without it.


## Makes a journal under [param test]'s root and returns it.
static func make_journal(test: QuestsTest) -> QuestJournal:
	var journal := QuestJournal.new()
	journal.id = "player"
	return test.add_node(journal) as QuestJournal


## Returns an active-state-less quest instance with the named counters (min 0, max 100).
static func make_quest(id: String, counters: PackedStringArray = PackedStringArray()) -> Quest:
	var quest := Quest.create(id)
	for counter_name in counters:
		quest.counter_list.append(QuestCounter.create(counter_name))
	return quest


## Adds a quest asset to the journal and returns the instance.
static func give(journal: QuestJournal, quest: Quest) -> Quest:
	return journal.add_quest(quest)


## Counts calls.
class Counter:
	extends RefCounted
	var count := 0

	func hit() -> void:
		count += 1


static func find_class_script(global_name: String) -> Script:
	for info in ProjectSettings.get_global_class_list():
		if info.get("class", "") == global_name:
			return load(info["path"]) as Script
	return null


## Adds a FactionManager with a default database plus the named factions. Returns it, or null.
static func make_faction_manager(test: QuestsTest, faction_names: PackedStringArray) -> Node:
	var manager_script := find_class_script("FactionManager")
	var database_script := find_class_script("FactionDatabase")
	if manager_script == null or database_script == null:
		return null
	var database: Resource = database_script.new()
	for faction_name in faction_names:
		database.call("create_faction", faction_name)
	var manager: Node = manager_script.new()
	manager.set("faction_database", database)
	return test.add_node(manager)
