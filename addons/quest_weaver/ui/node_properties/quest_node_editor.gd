# res://addons/quest_weaver/ui/node_properties/quest_node_editor.gd
@tool
class_name QuestNodeEditor
extends NodePropertyEditorBase

@onready var target_quest_id_edit: AutoCompleteLineEdit = %TargetQuestIdEdit
@onready var action_picker: OptionButton = %ActionPicker

func _ready() -> void:
	target_quest_id_edit.text_submitted.connect(_on_id_confirmed)
	target_quest_id_edit.focus_exited.connect(func(): _on_id_confirmed(target_quest_id_edit.text))
	
	action_picker.item_selected.connect(_on_action_changed)

func set_node_data(node_data: GraphNodeResource) -> void:
	super.set_node_data(node_data)
	if not node_data is QuestNodeResource: return
	
	QWEditorUtils.populate_quest_id_completer(target_quest_id_edit)
	target_quest_id_edit.text = node_data.target_quest_id
	
	action_picker.clear()
	for action_name in node_data.QuestAction.keys():
		action_picker.add_item(action_name.capitalize())
	action_picker.select(node_data.action)

func _on_id_confirmed(new_text: String):
	if is_instance_valid(edited_node_data) and edited_node_data.target_quest_id != new_text:
		property_update_requested.emit(edited_node_data.id, "target_quest_id", new_text)

func _on_action_changed(index: int) -> void:
	if is_instance_valid(edited_node_data) and edited_node_data.action != index:
		property_update_requested.emit(edited_node_data.id, "action", index)
