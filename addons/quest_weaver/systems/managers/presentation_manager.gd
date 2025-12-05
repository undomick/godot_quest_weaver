# res://addons/quest_weaver/systems/managers/presentation_manager.gd
class_name PresentationManager
extends Node

# The signal now carries the ID of the node that requested the message
signal presentation_completed(request_id: String)

var _queue: Array[Dictionary] = []
var _is_displaying := false
var _registry: PresentationRegistry
var _current_request_id: String = "" # Stores the ID of the currently displayed message

func _ready() -> void:
	var settings = QWConstants.Settings
	if is_instance_valid(settings) and ResourceLoader.exists(settings.presentation_registry_path):
		_registry = ResourceLoader.load(settings.presentation_registry_path)
	else:
		push_error("PresentationManager: PresentationRegistry not found!")

func queue_presentation(data: Dictionary):
	_queue.append(data)
	
	if not _is_displaying:
		_show_next_in_queue()

func _show_next_in_queue():
	if _queue.is_empty():
		_is_displaying = false
		return

	_is_displaying = true
	var data = _queue.pop_front()
	
	# Retrieve the ID we stored in the executor
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
	var panel_instance: BaseUIPanel = panel_scene.instantiate()
	
	if not is_instance_valid(panel_instance):
		_on_panel_completed()
		return
	
	get_tree().root.add_child(panel_instance)
	
	panel_instance.presentation_completed.connect(_on_panel_completed.bind(panel_instance), CONNECT_ONE_SHOT)

	panel_instance.present(data)

func _on_panel_completed(panel_instance: BaseUIPanel = null):
	if is_instance_valid(panel_instance):
		panel_instance.queue_free()
	
	# Emit the ID of the finished message so executors can check it
	presentation_completed.emit(_current_request_id)
	
	_show_next_in_queue()
