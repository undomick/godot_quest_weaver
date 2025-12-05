# res://addons/quest_weaver/core/quest_weaver_game_state.gd

extends Node

var variables: Dictionary = {}
var quest_states: Dictionary = {}

func _ready() -> void:
	var services = get_tree().root.get_node_or_null("QuestWeaverServices")
	if services:
		services.register_game_state(self)

# --- Variablen Management ---

func get_variable(key: String, default = null):
	return variables.get(key, default)

func set_variable(key: String, value: Variant):
	variables[key] = value

func has_variable(key: String) -> bool:
	return variables.has(key)

# --- Quest Status Management ---

func get_quest_status(quest_id: String) -> int:
	return quest_states.get(quest_id, 0)

func set_quest_status(quest_id: String, status: int) -> void:
	quest_states[quest_id] = status

# --- Save/Load Support ---

func get_save_data() -> Dictionary:
	return {
		"variables": variables.duplicate(true),
		"quest_states": quest_states.duplicate(true)
	}

func load_from_data(data: Dictionary) -> void:
	variables = data.get("variables", {}).duplicate(true)
	quest_states = data.get("quest_states", {}).duplicate(true)
