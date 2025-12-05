# res://addons/quest_weaver/editor/ui_runtime/quest_log_entry.gd
class_name QuestLogEntry
extends PanelContainer

signal selected(quest_id: String)

@onready var background_panel: PanelContainer = self

@export var stylebox_idle: StyleBox
@export var stylebox_active: StyleBox

var _quest_id: String

func _ready() -> void:
	set_active_state(false)

func set_quest_data(quest_data: Dictionary) -> void:
	self._quest_id = quest_data.get("id")
	var title_label: Label = find_child("QuestTitleLabel", true, false)
	if is_instance_valid(title_label):
		var title_string = quest_data.get("title", "ERROR_KEY")
		title_label.text = tr(title_string)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		selected.emit(_quest_id)

func set_active_state(is_active: bool) -> void:
	if not is_node_ready():
		await ready

	if is_active:
		if stylebox_active:
			background_panel.add_theme_stylebox_override("panel", stylebox_active)
	else:
		if stylebox_idle:
			background_panel.add_theme_stylebox_override("panel", stylebox_idle)
