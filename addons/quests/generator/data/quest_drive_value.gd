class_name QuestDriveValue
extends Resource
## A value, in the range [-100,+100], for a [QuestDrive].

@export var drive: QuestDrive
@export_range(-100.0, 100.0) var value := 0.0


static func create(p_drive: QuestDrive, p_value: float) -> QuestDriveValue:
	var dv := QuestDriveValue.new()
	dv.drive = p_drive
	dv.value = p_value
	return dv


## Returns a copy of this drive value.
func copy() -> QuestDriveValue:
	return QuestDriveValue.create(drive, value)
