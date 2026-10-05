class_name QuestDomainType
extends Resource
## An abstract area of the game world, such as a forest or the player's
## inventory. Quest generators plan with domain types rather than the actual
## [QuestDomain] nodes in the scene.

@export_multiline var description := ""
## The display name. If empty, the asset name is used.
@export var display_name := ""
## True for the domain type that represents the player's inventory.
@export var is_player_domain := false:
	set(value):
		is_player_domain = value
		if value:
			player_domain_instance = self

## The domain type that represents the player's inventory.
static var player_domain_instance: QuestDomainType


func get_asset_name() -> String:
	return QuestGeneratorData.asset_name_of(self)


## The display name, falling back to the asset name.
func get_display_name() -> String:
	return display_name if not display_name.is_empty() else get_asset_name()


func get_type_name() -> String:
	return "Player's Domain" if is_player_domain else get_asset_name()


## Sets the player domain type. If none is set and none exists, creates a default one.
static func set_player_domain_instance(new_instance: QuestDomainType) -> void:
	if new_instance != null:
		player_domain_instance = new_instance
	if player_domain_instance == null:
		var created := QuestDomainType.new()
		created.is_player_domain = true
		created.display_name = "Player"
		created.description = "Represents the player's inventory."
		player_domain_instance = created
