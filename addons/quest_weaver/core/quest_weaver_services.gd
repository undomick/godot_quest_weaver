# res://addons/quest_weaver/core/quest_weaver_services.gd
extends Node

signal game_state_ready
signal controller_ready
signal presentation_manager_ready
signal logger_ready

var quest_controller: QuestController = null
var presentation_manager: Node = null
var logger: QWLogger = null
var _game_state_instance: Node = null


func register_quest_controller(qc: QuestController) -> void:
	if quest_controller == null:
		quest_controller = qc
		controller_ready.emit()

func register_presentation_manager(pm: Node) -> void:
	if presentation_manager == null:
		presentation_manager = pm
		presentation_manager_ready.emit()

func register_logger(p_logger: QWLogger) -> void:
	if logger == null:
		logger = p_logger
		set_meta("logger_initialized", true)
		logger_ready.emit()

func register_game_state(instance: Node) -> void:
	if not is_instance_valid(_game_state_instance):
		_game_state_instance = instance
		game_state_ready.emit()
	else:
		push_warning("[QuestWeaverServices] Attempted to register GameState instance multiple times.")

func has_game_state() -> bool:
	return is_instance_valid(_game_state_instance)

func get_game_state() -> Node:
	if not is_instance_valid(_game_state_instance):
		push_warning("[QuestWeaverServices] GameState was requested before it was registered.")
	return _game_state_instance
