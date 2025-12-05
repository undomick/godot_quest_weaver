# res://addons/quest_weaver/nodes/flow/jump_node/jump_node_editor.gd
@tool
class_name JumpNodeEditor
extends NodePropertyEditorBase

@onready var target_edit: LineEdit = %TargetNameEdit

func _ready() -> void:
	target_edit.text_submitted.connect(func(_text): _on_target_confirmed())
	target_edit.focus_exited.connect(_on_target_confirmed)

func set_node_data(node_data: GraphNodeResource) -> void:
	super.set_node_data(node_data)
	if not node_data is JumpNodeResource: return
	
	target_edit.text = node_data.target_anchor_name

func _on_target_confirmed() -> void:
	var new_text = target_edit.text
	if is_instance_valid(edited_node_data) and edited_node_data.target_anchor_name != new_text:
		property_update_requested.emit(edited_node_data.id, "target_anchor_name", new_text)
