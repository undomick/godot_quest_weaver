# res://addons/quest_weaver/nodes/logic/end_scope_node/end_scope_node_editor.gd
@tool
extends NodePropertyEditorBase

@onready var scope_id_edit: LineEdit = %ScopeIDEdit

func _ready() -> void:
	scope_id_edit.text_submitted.connect(func(_text): _on_scope_id_confirmed())
	scope_id_edit.focus_exited.connect(_on_scope_id_confirmed)

func set_node_data(node_data: GraphNodeResource) -> void:
	super.set_node_data(node_data)
	if not node_data is EndScopeNodeResource: return
	
	scope_id_edit.text = node_data.scope_id

func _on_scope_id_confirmed() -> void:
	var new_text = scope_id_edit.text
	if is_instance_valid(edited_node_data) and edited_node_data.scope_id != new_text:
		property_update_requested.emit(edited_node_data.id, "scope_id", new_text)
