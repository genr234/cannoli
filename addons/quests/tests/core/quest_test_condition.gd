class_name QuestTestCondition
extends QuestCondition
## A condition for tests that becomes true when [method fire] is called while checking.

## Counts how many times checking started.
var start_count := 0
## Counts how many times checking stopped.
var stop_count := 0


func start_checking(true_callback: Callable) -> void:
	super(true_callback)
	start_count += 1


func stop_checking() -> void:
	if is_checking:
		stop_count += 1
	super()


## Makes the condition true if it is checking.
func fire() -> void:
	if is_checking:
		set_true()


static func make() -> QuestTestCondition:
	return QuestTestCondition.new()
