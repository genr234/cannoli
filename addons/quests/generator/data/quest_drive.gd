class_name QuestDrive
extends Resource
## A personality trait, such as Safety or Compassion. Entity types hold values for
## drives, and verb motives are matched to a quest giver's drive values.

## Description of this drive, for your own reference.
@export_multiline var description := ""


## The asset name of this drive (the resource name, or the file name).
func get_asset_name() -> String:
	return QuestGeneratorData.asset_name_of(self)
