# res://addons/quest_weaver/ui/node_properties/complete_objective_node_editor.gd
@tool
class_name CompleteObjectiveNodeEditor
extends NodePropertyEditorBase

@onready var target_id_edit: LineEdit = %TargetIdEdit

func _ready():
	target_id_edit.text_submitted.connect(func(_new_text): _on_id_confirmed())
	target_id_edit.focus_exited.connect(_on_id_confirmed)

func set_node_data(node_data: GraphNodeResource):
	super.set_node_data(node_data)
	if not node_data is CompleteObjectiveNodeResource: return
	
	target_id_edit.text = node_data.target_objective_id

func _on_id_confirmed():
	var new_id = target_id_edit.text
	# Check if the ID has actually changed before creating a history entry.
	if is_instance_valid(edited_node_data) and edited_node_data.target_objective_id != new_id:
		property_update_requested.emit(edited_node_data.id, "target_objective_id", new_id)
