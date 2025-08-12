# res://addons/quest_weaver/ui/editors/quest_control_node_editor.gd
@tool
extends NodePropertyEditorBase

@onready var quest_path_edit: LineEdit = %QuestPathEdit
@onready var browse_button: Button = %BrowseButton


func _ready() -> void:
	quest_path_edit.text_submitted.connect(_on_path_changed)
	browse_button.pressed.connect(_on_browse_pressed)

func set_node_data(node_data: GraphNodeResource) -> void:
	super.set_node_data(node_data)
	quest_path_edit.text = node_data.get("quest_path")

func _on_path_changed(new_path: String) -> void:
	property_update_requested.emit(edited_node_data.id, "quest_path", new_path)

func _on_browse_pressed() -> void:
	var dialog = QWConstants.QuestFileDialogScene.instantiate()
	get_tree().root.add_child(dialog)
	dialog.path_confirmed.connect(func(path): _on_path_changed(path); quest_path_edit.text = path)
	dialog.prompt(QuestFileDialog.Mode.OPEN_FILE)
