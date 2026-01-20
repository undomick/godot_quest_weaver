# res://addons/quest_weaver/nodes/flow/branch_node/branch_node_editor.gd
@tool
class_name BranchNodeEditor
extends NodePropertyEditorBase

const ConditionEditorScene = preload("res://addons/quest_weaver/editor/conditions/condition_editor.tscn")

@onready var operator_picker: OptionButton = %OperatorPicker
@onready var conditions_list: VBoxContainer = %ConditionsList
@onready var add_button: Button = %AddConditionButton

func _ready() -> void:
	operator_picker.item_selected.connect(_on_operator_changed)
	add_button.pressed.connect(_on_add_condition_pressed)
	
	# --- TOOLTIPS ---
	operator_picker.tooltip_text = "Determines how the list of conditions is evaluated:\n" + \
		"- AND: All conditions must be true.\n" + \
		"- OR: At least one condition must be true.\n" + \
		"- NAND: Returns true if at least one condition is false (Not AND).\n" + \
		"- NOR: Returns true only if all conditions are false (Not OR)."
	
	add_button.tooltip_text = "Add a new condition to evaluate."

func set_node_data(node_data: GraphNodeResource) -> void:
	super.set_node_data(node_data)
	if not node_data is BranchNodeResource: return
	
	operator_picker.clear()
	for op_name in node_data.LogicOperator.keys():
		operator_picker.add_item(op_name)
	operator_picker.select(node_data.operator)
	
	call_deferred("_rebuild_conditions_list")

func _rebuild_conditions_list() -> void:
	for child in conditions_list.get_children():
		child.queue_free()
		
	var branch_node: BranchNodeResource = edited_node_data
	if not is_instance_valid(branch_node): return

	for i in range(branch_node.conditions.size()):
		var condition = branch_node.conditions[i]
		var entry_container = HBoxContainer.new()
		entry_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var editor_instance = ConditionEditorScene.instantiate()
		editor_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry_container.add_child(editor_instance)

		var remove_button = Button.new()
		remove_button.text = "X"
		remove_button.pressed.connect(_on_remove_condition_requested.bind(condition))
		entry_container.add_child(remove_button)

		conditions_list.add_child(entry_container)
		
		editor_instance.edit_condition(condition)
		editor_instance.property_changed.connect(
			func(prop_name: String, new_value: Variant):
				property_update_requested.emit(edited_node_data.id, prop_name, new_value, condition)
		)
		editor_instance.rebuild_requested.connect(_rebuild_conditions_list)

func _on_add_condition_pressed() -> void:
	complex_action_requested.emit(edited_node_data.id, "add_condition", {})

func _on_operator_changed(index: int) -> void:
	# Check if the value has actually changed before creating a history entry.
	if is_instance_valid(edited_node_data) and edited_node_data.operator != index:
		property_update_requested.emit(edited_node_data.id, "operator", index)

func _on_remove_condition_requested(condition_to_remove: ConditionResource) -> void:
	var payload = {"condition": condition_to_remove}
	complex_action_requested.emit(edited_node_data.id, "remove_condition", payload)
