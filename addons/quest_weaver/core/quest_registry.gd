# res://addons/quest_weaver/core/quest_registry.gd
@tool
class_name QuestRegistry
extends Resource

## Maps Logical Quest IDs to their resource file paths.
## Format: { "kill_rats_main": "res://quests/act_1/rats.quest" }
@export var quest_path_map: Dictionary = {}

## Helper to get just the list of IDs (for Autocomplete/Dropdowns)
func get_all_ids() -> Array:
	return quest_path_map.keys()
