# res://core/game_state.gd

extends Node

enum QuestState { INACTIVE, ACTIVE, COMPLETED, FAILED }

var variables: Dictionary = {}
var quest_states: Dictionary = {}

func _ready() -> void:
	QuestWeaverServices.register_game_state(self)

func get_variable(key: String, default = null):
	return variables.get(key, default)

func set_variable(key: String, value: Variant):
	variables[key] = value

func get_quest_status(quest_path: String) -> int:
	return quest_states.get(quest_path, QuestState.INACTIVE)

func set_quest_status(quest_path: String, new_status: QuestState):
	quest_states[quest_path] = new_status
	print("GameState: Status of '%s' set to %s" % [quest_path.get_file(), QuestState.keys()[new_status]])

# --- Save/Load Funktionalität ---

## Sammelt alle Daten dieses Singletons für das Speichern.
func get_save_data() -> Dictionary:
	return {
		"variables": variables.duplicate(true),
		"quest_states": quest_states.duplicate(true)
	}

## Stellt den Zustand aus einem geladenen Daten-Dictionary wieder her.
func load_from_data(data: Dictionary):
	variables.clear()
	quest_states.clear()
	
	if data.has("variables"):
		variables = data["variables"]
	if data.has("quest_states"):
		quest_states = data["quest_states"]
	
	print("GameState data restored. Loaded %d variables and %d quest states." % [variables.size(), quest_states.size()])
