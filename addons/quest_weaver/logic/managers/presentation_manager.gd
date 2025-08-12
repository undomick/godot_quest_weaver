# res://addons/quest_weaver/logic/presentation_manager.gd
class_name PresentationManager
extends Node

signal presentation_completed

var _queue: Array[Dictionary] = []
var _is_displaying := false
var _registry: PresentationRegistry

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
	
	presentation_completed.emit()
	_show_next_in_queue()
