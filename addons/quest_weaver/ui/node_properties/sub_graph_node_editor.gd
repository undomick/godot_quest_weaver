# res://addons/quest_weaver/ui/node_properties/sub_graph_node_editor.gd
@tool
extends NodePropertyEditorBase

signal dive_in_requested(graph_path: String)

@onready var path_edit: LineEdit = %QuestGraphPathEdit
@onready var browse_button: Button = %BrowseButton
@onready var wait_checkbox: CheckBox = %WaitForCompletionCheckbox
@onready var dive_in_button: Button = %DiveInButton

func _ready() -> void:
	path_edit.text_submitted.connect(func(_text): _on_path_confirmed())
	path_edit.focus_exited.connect(_on_path_confirmed)
	wait_checkbox.toggled.connect(_on_wait_toggled)
	dive_in_button.pressed.connect(_on_dive_in_pressed)
	browse_button.pressed.connect(_on_browse_button_pressed)

func set_node_data(node_data: GraphNodeResource) -> void:
	super.set_node_data(node_data)
	if not node_data is SubGraphNodeResource: return
	
	path_edit.text = node_data.quest_graph_path
	wait_checkbox.button_pressed = node_data.wait_for_completion
	_update_dive_in_button_state()

func _can_drop_data(_at_position, data) -> bool:
	if data is Dictionary and data.get("type") == "files":
		if data.get("files", []).size() > 0:
			var file_path = data.get("files")[0]
			return file_path.ends_with(".quest")
	return false

func _drop_data(_at_position, data) -> void:
	var file_path = data.get("files")[0]
	_on_path_confirmed(file_path)

func _on_browse_button_pressed():
	var dialog: QuestFileDialog = QWConstants.QuestFileDialogScene.instantiate()
	get_tree().root.add_child(dialog)
	dialog.path_confirmed.connect(_on_path_confirmed)
	dialog.prompt(QuestFileDialog.Mode.OPEN_FILE)

func _on_path_confirmed(new_path: String = ""):
	if new_path.is_empty():
		new_path = path_edit.text

	# Visually update the text edit immediately for responsiveness
	path_edit.text = new_path
	
	if is_instance_valid(edited_node_data) and edited_node_data.quest_graph_path != new_path:
		property_update_requested.emit(edited_node_data.id, "quest_graph_path", new_path)

	_update_dive_in_button_state()

func _on_wait_toggled(button_state: bool):
	if is_instance_valid(edited_node_data) and edited_node_data.wait_for_completion != button_state:
		property_update_requested.emit(edited_node_data.id, "wait_for_completion", button_state)

func _on_dive_in_pressed():
	if not dive_in_button.disabled:
		dive_in_requested.emit(edited_node_data.quest_graph_path)

func _update_dive_in_button_state():
	var path = path_edit.text
	dive_in_button.disabled = path.is_empty() or not ResourceLoader.exists(path)
