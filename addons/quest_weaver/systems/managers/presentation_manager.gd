# res://addons/quest_weaver/systems/managers/presentation_manager.gd
class_name PresentationManager
extends Node

# The signal carries the ID of the node that requested the message
signal presentation_completed(request_id: String)

var _queue: Array[Dictionary] = []
var _is_displaying := false
var _registry: PresentationRegistry
var _current_request_id: String = "" 
var _current_panel_instance: BaseUIPanel = null # Reference for skipping

func _ready() -> void:
	var settings = QWConstants.get_settings()
	if is_instance_valid(settings) and ResourceLoader.exists(settings.presentation_registry_path):
		_registry = ResourceLoader.load(settings.presentation_registry_path)
	else:
		push_error("PresentationManager: PresentationRegistry not found!")

func queue_presentation(data: Dictionary) -> void:
	_queue.append(data)
	
	if not _is_displaying:
		_show_next_in_queue()

func force_close_current() -> void:
	# Called by QuestController when skipping/resetting
	if is_instance_valid(_current_panel_instance):
		_current_panel_instance.queue_free()
		_current_panel_instance = null
	
	if _is_displaying:
		# Emit the signal so the executor loop breaks and the flow continues
		presentation_completed.emit(_current_request_id)
		_is_displaying = false
		_current_request_id = ""
		
		# Optional: Clear the rest of the queue on skip to avoid "spamming" the next messages
		_queue.clear()

func _show_next_in_queue() -> void:
	if _queue.is_empty():
		_is_displaying = false
		return

	_is_displaying = true
	var data = _queue.pop_front()
	
	_current_request_id = data.get("_node_id", "")
	
	var template: UIPanelTemplateResource = _registry.entries.get(data.get("type", "Default"))
	if not is_instance_valid(template):
		_on_panel_completed()
		return
	
	var scene_path = template.panel_scene_path
	
	if not ResourceLoader.exists(scene_path):
		_on_panel_completed()
		return
	
	var panel_scene = load(scene_path)
	# Instantiation and storage of reference
	var panel_instance: BaseUIPanel = panel_scene.instantiate()
	_current_panel_instance = panel_instance
	
	if not is_instance_valid(panel_instance):
		_on_panel_completed()
		return
	
	get_tree().root.add_child(panel_instance)
	
	panel_instance.presentation_completed.connect(_on_panel_completed.bind(panel_instance), CONNECT_ONE_SHOT)

	panel_instance.present(data)

func _on_panel_completed(panel_instance: BaseUIPanel = null) -> void:
	if is_instance_valid(panel_instance):
		panel_instance.queue_free()
	
	_current_panel_instance = null
	
	presentation_completed.emit(_current_request_id)
	
	_show_next_in_queue()
