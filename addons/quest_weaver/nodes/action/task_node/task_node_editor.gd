# res://addons/quest_weaver/nodes/action/task_node/task_node_editor.gd
@tool
extends NodePropertyEditorBase

@onready var objectives_list: VBoxContainer = %ObjectivesList
@onready var add_objective_button: Button = %AddObjectiveButton

var _ui_entry_map: Dictionary = {}

func _ready() -> void:
	add_objective_button.pressed.connect(_on_add_objective_pressed)

func set_node_data(node_data: GraphNodeResource) -> void:
	super.set_node_data(node_data)
	if not node_data is TaskNodeResource:
		for child in objectives_list.get_children():
			child.queue_free()
		_ui_entry_map.clear()
		return
	
	_rebuild_objectives_list()

func _rebuild_objectives_list() -> void:
	for child in objectives_list.get_children():
		child.queue_free()
	_ui_entry_map.clear()

	var task_node: TaskNodeResource = edited_node_data
	if not is_instance_valid(task_node): return

	for objective in task_node.objectives:
		_add_objective_ui(objective)

func _add_objective_ui(objective_resource: ObjectiveResource):
	var entry_instance: ObjectiveEditorEntry = QWConstants.ObjectiveEditorEntryScene.instantiate()
		
	entry_instance.description_changed.connect(_on_objective_description_changed.bind(objective_resource))
	entry_instance.trigger_type_changed.connect(_on_objective_trigger_type_changed.bind(objective_resource))
	entry_instance.trigger_param_changed.connect(_on_objective_trigger_param_changed.bind(objective_resource))
	entry_instance.delete_requested.connect(_on_objective_delete_requested.bind(objective_resource))
	
	if entry_instance.has_signal("direct_property_changed"):
		entry_instance.direct_property_changed.connect(
			_on_objective_direct_property_changed.bind(objective_resource)
		)

	objectives_list.add_child(entry_instance)
	entry_instance.set_objective(objective_resource)
	_ui_entry_map[objective_resource] = entry_instance

func _remove_objective_ui(objective_resource: ObjectiveResource) -> void:
	if _ui_entry_map.has(objective_resource):
		_ui_entry_map[objective_resource].queue_free()
		_ui_entry_map.erase(objective_resource)

func _on_add_objective_pressed() -> void:
	complex_action_requested.emit(edited_node_data.id, "add_objective", {})

func _on_objective_delete_requested(objective: ObjectiveResource) -> void:
	var payload = {"objective": objective}
	complex_action_requested.emit(edited_node_data.id, "remove_objective", payload)

# --- Signal Handlers for property changes (remain the same) ---

func _on_objective_direct_property_changed(property_name: String, new_value: Variant, objective: ObjectiveResource):
	property_update_requested.emit(edited_node_data.id, property_name, new_value, objective)

func _on_objective_description_changed(new_text: String, objective: ObjectiveResource) -> void:
	property_update_requested.emit(edited_node_data.id, "description", new_text, objective)

func _on_objective_trigger_type_changed(new_type_index: int, objective: ObjectiveResource) -> void:
	property_update_requested.emit(edited_node_data.id, "trigger_type", new_type_index, objective)

func _on_objective_trigger_param_changed(param_name: String, new_value: Variant, objective: ObjectiveResource) -> void:
	var payload = {"objective": objective, "param_name": param_name, "param_value": new_value}
	complex_action_requested.emit(edited_node_data.id, "update_objective_trigger_param", payload)
