@tool
class_name ParallelNodeEditor
extends NodePropertyEditorBase

signal ports_need_refresh
signal connections_from_port_removal_requested(port_index: int)

@onready var outputs_container: VBoxContainer = %OutputsContainer
@onready var add_output_button: Button = %AddOutputButton

func _ready():
	add_output_button.pressed.connect(_on_add_output_pressed)

func set_node_data(node_data: GraphNodeResource):
	super.set_node_data(node_data)
	if not node_data is ParallelNodeResource: return
	_rebuild_outputs_list()

func _rebuild_outputs_list():
	for child in outputs_container.get_children():
		child.queue_free()
		
	var parallel_node: ParallelNodeResource = edited_node_data
	if not is_instance_valid(parallel_node): return

	for i in range(parallel_node.outputs.size()):
		var output_info = parallel_node.outputs[i]
		var entry: ParallelOutputEditorEntry = QWConstants.OutputEntryScene.instantiate()
		
		entry.remove_requested.connect(_on_remove_output_pressed.bind(i))
		entry.name_changed.connect(_on_output_name_changed.bind(i))
		entry.property_changed.connect(_on_output_condition_property_changed.bind(i))
		entry.rebuild_requested.connect(_rebuild_outputs_list)
		
		outputs_container.add_child(entry)
		entry.set_output_info(output_info)

func _on_add_output_pressed() -> void:
	complex_action_requested.emit(edited_node_data.id, "add_parallel_output", {})

func _on_remove_output_pressed(index: int) -> void:
	#connections_from_port_removal_requested.emit(index)

	var payload = {"index": index}
	complex_action_requested.emit(edited_node_data.id, "remove_parallel_output", payload)

func _on_output_name_changed(new_name: String, index: int) -> void:
	var payload = {"index": index, "new_name": new_name}
	complex_action_requested.emit(edited_node_data.id, "update_parallel_port_name", payload)

func _on_output_condition_property_changed(property_name: String, new_value: Variant, index: int) -> void:
	var parallel_node = edited_node_data as ParallelNodeResource
	if is_instance_valid(parallel_node) and index < parallel_node.outputs.size():
		var target_condition_resource = parallel_node.outputs[index].condition
		if is_instance_valid(target_condition_resource):
			property_update_requested.emit(edited_node_data.id, property_name, new_value, target_condition_resource)
