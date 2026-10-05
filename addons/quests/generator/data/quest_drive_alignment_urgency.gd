class_name QuestDriveAlignmentUrgency
extends QuestUrgencyFunction
## Urgency based on how well the observer's and the observed entity's drive values align.

## Multiply the urgency by this curve, where x is the number of entities the observer is aware of.
@export var entity_count_multiplier: Curve = QuestCurves.default_entity_count_multiplier()


func get_type_name() -> String:
	return "By Drive Alignment"


func compute(world_model: QuestWorldModel) -> float:
	if not _validate(world_model):
		return 0.0
	return _get_drive_alignment(world_model.observer.entity_type.drive_values, world_model.observed.entity_type.drive_values)


func _get_drive_alignment(observer_values: Array[QuestDriveValue], observed_values: Array[QuestDriveValue]) -> float:
	var total := 0.0
	var count := 0
	for observed_value in observed_values:
		if observed_value == null or observed_value.drive == null:
			continue
		var observer_value := _lookup(observer_values, observed_value.drive)
		if observer_value == null:
			continue
		var difference := absf(observed_value.value - observer_value.value)
		total += (200.0 - difference) / 200.0
		count += 1
	return 0.0 if count == 0 else total / float(count)


func _lookup(values: Array[QuestDriveValue], drive: QuestDrive) -> QuestDriveValue:
	for v in values:
		if v != null and v.drive == drive:
			return v
	return null
