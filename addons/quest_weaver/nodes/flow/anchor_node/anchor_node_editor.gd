# res://addons/quest_weaver/nodes/flow/anchor_node/anchor_node_editor.gd
@tool
class_name AnchorNodeEditor
extends NodePropertyEditorBase

@onready var name_edit: LineEdit = %AnchorNameEdit

func _ready() -> void:
	name_edit.text_submitted.connect(func(_text): _on_name_confirmed())
	name_edit.focus_exited.connect(_on_name_confirmed)

func set_node_data(node_data: GraphNodeResource) -> void:
	super.set_node_data(node_data)
	if not node_data is AnchorNodeResource: return
	
	name_edit.text = node_data.anchor_name

func _on_name_confirmed() -> void:
	var new_text = name_edit.text
	if is_instance_valid(edited_node_data) and edited_node_data.anchor_name != new_text:
		property_update_requested.emit(edited_node_data.id, "anchor_name", new_text)
