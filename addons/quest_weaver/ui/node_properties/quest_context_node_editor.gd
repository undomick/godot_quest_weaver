# res://addons/quest_weaver/ui/node_properties/quest_context_node_editor.gd
@tool
extends NodePropertyEditorBase

@onready var quest_id_edit: LineEdit = %QuestIdEdit
@onready var quest_type_picker: OptionButton = %QuestTypePicker
@onready var title_edit: LineEdit = %TitleEdit
@onready var description_edit: TextEdit = %DescriptionEdit
@onready var log_on_start_edit: TextEdit = %LogOnStartEdit

func _ready() -> void:
	quest_id_edit.text_submitted.connect(func(_text): _on_quest_id_confirmed())
	quest_id_edit.focus_exited.connect(_on_quest_id_confirmed)
	
	quest_type_picker.item_selected.connect(_on_quest_type_changed)
	
	title_edit.text_submitted.connect(func(_text): _on_title_confirmed())
	title_edit.focus_exited.connect(_on_title_confirmed)
	
	description_edit.focus_exited.connect(_on_description_confirmed)
	log_on_start_edit.focus_exited.connect(_on_log_on_start_confirmed)

func set_node_data(node_data: GraphNodeResource) -> void:
	super.set_node_data(node_data)
	if not node_data is QuestContextNodeResource: return
	
	quest_id_edit.text = node_data.quest_id
	title_edit.text = node_data.quest_title
	description_edit.text = node_data.quest_description
	log_on_start_edit.text = node_data.log_on_start

	quest_type_picker.clear()
	for type_name in node_data.QuestType.keys():
		quest_type_picker.add_item(type_name.capitalize())
	quest_type_picker.select(node_data.quest_type)

func _on_quest_id_confirmed() -> void:
	var new_text = quest_id_edit.text
	if new_text.is_empty():
		quest_id_edit.text = edited_node_data.quest_id # Revert UI
		return

	if is_instance_valid(edited_node_data) and edited_node_data.quest_id != new_text:
		property_update_requested.emit(edited_node_data.id, "quest_id", new_text)

func _on_quest_type_changed(index: int):
	if is_instance_valid(edited_node_data) and edited_node_data.quest_type != index:
		property_update_requested.emit(edited_node_data.id, "quest_type", index)

func _on_title_confirmed() -> void:
	var new_text = title_edit.text
	if is_instance_valid(edited_node_data) and edited_node_data.quest_title != new_text:
		property_update_requested.emit(edited_node_data.id, "quest_title", new_text)

func _on_description_confirmed() -> void:
	var new_text = description_edit.text
	if is_instance_valid(edited_node_data) and edited_node_data.quest_description != new_text:
		property_update_requested.emit(edited_node_data.id, "quest_description", new_text)

func _on_log_on_start_confirmed() -> void:
	var new_text = log_on_start_edit.text
	if is_instance_valid(edited_node_data) and edited_node_data.log_on_start != new_text:
		property_update_requested.emit(edited_node_data.id, "log_on_start", new_text)
