# res://addons/quest_weaver/ui/node_properties/synchronize_node_editor.gd
@tool
class_name SynchronizeNodeEditor
extends NodePropertyEditorBase

const InputEntryScene = preload("res://addons/quest_weaver/ui/components/synchronize_input_editor_entry.tscn")
const OutputEntryScene = preload("res://addons/quest_weaver/ui/components/synchronize_output_editor_entry.tscn")

signal ports_need_refresh

@onready var completion_mode_picker: OptionButton = %CompletionModePicker
@onready var required_inputs_label: Label = %RequiredInputsLabel
@onready var required_inputs_spinbox: SpinBox = %RequiredInputsSpinBox
@onready var inputs_container: VBoxContainer = %InputsContainer
@onready var add_input_button: Button = %AddInputButton
@onready var outputs_container: VBoxContainer = %OutputsContainer
@onready var add_output_button: Button = %AddOutputButton

var _is_setting_up := false
var _required_inputs_undo_value: int = 0

func _ready():
	completion_mode_picker.clear()
	
	for mode_name in SynchronizeNodeResource.CompletionMode.keys():
		completion_mode_picker.add_item(mode_name)
	
	completion_mode_picker.item_selected.connect(_on_completion_mode_changed)
	
	# Connect focus signals for SpinBox to bundle UndoRedo actions
	required_inputs_spinbox.focus_entered.connect(_on_required_inputs_edit_started)
	required_inputs_spinbox.focus_exited.connect(_on_required_inputs_edit_finished)
	
	add_input_button.pressed.connect(_on_add_input_pressed)
	add_output_button.pressed.connect(_on_add_output_pressed)

func set_node_data(node_data: GraphNodeResource):
	super.set_node_data(node_data)
	if not node_data is SynchronizeNodeResource: return
	
	_is_setting_up = true
	completion_mode_picker.select(node_data.completion_mode)
	_update_required_inputs_visibility()
	
	required_inputs_spinbox.max_value = node_data.inputs.size()
	required_inputs_spinbox.value = node_data.required_input_count
	
	call_deferred("_finish_setup")
	
	_rebuild_inputs_list()
	_rebuild_outputs_list()

func _finish_setup():
	_is_setting_up = false

func _update_required_inputs_visibility():
	var show = (completion_mode_picker.selected == SynchronizeNodeResource.CompletionMode.WAIT_FOR_N_INPUTS)
	required_inputs_label.visible = show
	required_inputs_spinbox.visible = show

func _rebuild_inputs_list():
	for child in inputs_container.get_children(): child.queue_free()
	
	var sync_node: SynchronizeNodeResource = edited_node_data
	if not is_instance_valid(sync_node): return

	for i in range(sync_node.inputs.size()):
		var input_port = sync_node.inputs[i]
		var entry = InputEntryScene.instantiate()
		entry.name_changed.connect(_on_input_name_changed.bind(i))
		entry.remove_requested.connect(_on_remove_input_pressed.bind(i))
		inputs_container.add_child(entry)
		entry.set_input_port(input_port)

func _rebuild_outputs_list():
	for child in outputs_container.get_children(): child.queue_free()

	var sync_node: SynchronizeNodeResource = edited_node_data
	if not is_instance_valid(sync_node): return

	for i in range(sync_node.outputs.size()):
		var output_port = sync_node.outputs[i]
		var entry = OutputEntryScene.instantiate()
		entry.name_changed.connect(_on_output_name_changed.bind(i))
		entry.property_changed.connect(_on_output_condition_property_changed.bind(i))
		entry.type_changed.connect(_on_output_condition_type_changed.bind(i))
		entry.remove_requested.connect(_on_remove_output_pressed.bind(i))
		outputs_container.add_child(entry)
		entry.display_data(output_port)

func _on_completion_mode_changed(index: int):
	if _is_setting_up: return
	if is_instance_valid(edited_node_data) and edited_node_data.completion_mode != index:
		property_update_requested.emit(edited_node_data.id, "completion_mode", index)
	_update_required_inputs_visibility()

func _on_required_inputs_edit_started() -> void:
	if is_instance_valid(edited_node_data):
		_required_inputs_undo_value = edited_node_data.required_input_count

func _on_required_inputs_edit_finished() -> void:
	if _is_setting_up: return
	var new_value = int(required_inputs_spinbox.value)
	if is_instance_valid(edited_node_data) and _required_inputs_undo_value != new_value:
		property_update_requested.emit(edited_node_data.id, "required_input_count", new_value)

func _on_add_input_pressed():
	complex_action_requested.emit(edited_node_data.id, "add_sync_input", {})

func _on_remove_input_pressed(index: int):
	var payload = {"index": index}
	complex_action_requested.emit(edited_node_data.id, "remove_sync_input", payload)

func _on_input_name_changed(new_name: String, index: int):
	var payload = {"index": index, "new_name": new_name}
	complex_action_requested.emit(edited_node_data.id, "update_sync_input_name", payload)

func _on_add_output_pressed():
	complex_action_requested.emit(edited_node_data.id, "add_sync_output", {})
	await get_tree().process_frame
	_rebuild_outputs_list()

func _on_remove_output_pressed(index: int):
	complex_action_requested.emit(edited_node_data.id, "remove_sync_output", {"index": index})
	await get_tree().process_frame
	_rebuild_outputs_list()

func _on_output_name_changed(new_name: String, index: int):
	var payload = {"index": index, "new_name": new_name}
	complex_action_requested.emit(edited_node_data.id, "update_sync_output_name", payload)

func _on_output_condition_property_changed(property_name: String, new_value: Variant, index: int):
	var sync_node = edited_node_data as SynchronizeNodeResource
	var condition_resource = sync_node.outputs[index].condition
	property_update_requested.emit(edited_node_data.id, property_name, new_value, condition_resource)

func _on_output_condition_type_changed(_new_script: Script, index: int):
	_rebuild_outputs_list()
