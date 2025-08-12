# res://addons/quest_weaver/ui/quest_log_ui.gd
class_name QuestLogUI
extends CanvasLayer

const QuestLogEntryScene = preload("./quest_log_entry.tscn")
const QuestCategoryHeader = preload("./quest_category_header.gd")

@onready var quest_list: VBoxContainer = %QuestListContainer
@onready var active_quests_header: QuestCategoryHeader = %ActiveQuestsHeader
@onready var completed_quests_header: QuestCategoryHeader = %CompletedQuestsHeader
@onready var failed_quests_header: QuestCategoryHeader = %FailedQuestsHeader
@onready var detail_title_label: Label = %DetailTitleLabel
@onready var detail_description_label: RichTextLabel = %DetailDescriptionLabel
@onready var detail_objectives_list: VBoxContainer = %DetailObjectivesList
@onready var detail_log_list: VBoxContainer = %DetailLogList

@export var toggle_log_action: StringName = &"toggle_quest_log"

var _all_quest_entries: Array[QuestLogEntry] = []
var quest_controller: QuestController
var _current_selected_quest_id: String = ""
var _list_needs_redraw := false
var _redraw_request_count_this_frame := 0


func _ready() -> void:
	self.visible = false
	
	active_quests_header.set_category_name("Active Quests")
	completed_quests_header.set_category_name("Completed Quests")
	failed_quests_header.set_category_name("Failed Quests")
	
	quest_controller = QuestWeaverServices.quest_controller
	if is_instance_valid(quest_controller):
		_initialize_connections()
	else:
		QuestWeaverServices.controller_ready.connect(_on_controller_ready, CONNECT_ONE_SHOT)

func _initialize_connections() -> void:
	quest_controller.quest_started.connect(_on_quest_list_changed)
	quest_controller.quest_completed.connect(_on_quest_list_changed)
	quest_controller.quest_failed.connect(_on_quest_list_changed)
	quest_controller.quest_data_changed.connect(_on_quest_data_changed)

	if self.visible:
		_request_list_redraw()

func _on_controller_ready() -> void:
	quest_controller = QuestWeaverServices.quest_controller
	if is_instance_valid(quest_controller):
		_initialize_connections()
	else:
		push_error("QuestLogUI: Controller_ready signal received, but controller is still invalid!")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_log_action):
		self.visible = not self.visible
		if self.visible:
			_request_list_redraw()

func _on_quest_list_changed(_quest_id: String) -> void:
	_request_list_redraw()

func _on_quest_data_changed(quest_id: String) -> void:
	_request_list_redraw()
	
	if self.visible and quest_id == _current_selected_quest_id:
		_update_detail_view()

func _request_list_redraw() -> void:
	_redraw_request_count_this_frame += 1
	if not self.visible or _list_needs_redraw:
		return
	
	_list_needs_redraw = true
	call_deferred("_process_redraw")

func _process_redraw() -> void:
	if not _list_needs_redraw:
		return
	
	_list_needs_redraw = false
	if self.visible:
		_redraw_quest_list()
		
		active_quests_header.update_display()
		completed_quests_header.update_display()
		failed_quests_header.update_display()
		
		_update_detail_view()

func _redraw_quest_list() -> void:
	active_quests_header.clear_entries()
	completed_quests_header.clear_entries()
	failed_quests_header.clear_entries()
	_all_quest_entries.clear()
	
	var all_quests = quest_controller.get_all_managed_quests_data()
	
	for quest_data in all_quests:
		var status = quest_data.get("status")
		if status == QWConstants.QWEnums.QuestState.INACTIVE:
			continue

		var entry_instance: QuestLogEntry = QuestLogEntryScene.instantiate()
		
		entry_instance.set_quest_data(quest_data) 
		entry_instance.selected.connect(_on_quest_entry_selected)
		_all_quest_entries.append(entry_instance)
		
		var quest_type = quest_data.get("quest_type", QuestContextNodeResource.QuestType.SIDE)
		match status:
			QWConstants.QWEnums.QuestState.ACTIVE:
				active_quests_header.add_quest_entry(entry_instance, quest_type)
			QWConstants.QWEnums.QuestState.COMPLETED:
				completed_quests_header.add_quest_entry(entry_instance, quest_type)
			QWConstants.QWEnums.QuestState.FAILED:
				failed_quests_header.add_quest_entry(entry_instance, quest_type)
	
	_update_selection_and_highlights(all_quests)

func _update_selection_and_highlights(all_quests: Array) -> void:
	var all_quest_ids = all_quests.map(func(q): return q.id)
	
	if not _current_selected_quest_id in all_quest_ids:
		
		var active_quests = all_quests.filter(func(q): return q.get("status") == QWConstants.QWEnums.QuestState.ACTIVE)
		if not active_quests.is_empty():
			_on_quest_entry_selected(active_quests[0].id)
		else:
			_clear_detail_view()
			_update_entry_highlights()
	else:
		_update_entry_highlights()

func _on_quest_entry_selected(quest_id: String) -> void:
	if _current_selected_quest_id == quest_id:
		return

	_current_selected_quest_id = quest_id
	
	_update_entry_highlights()
	_update_detail_view()

func _update_entry_highlights() -> void:
	for entry in _all_quest_entries:
		entry.set_active_state(entry._quest_id == _current_selected_quest_id)

func _clear_detail_view() -> void:
	_current_selected_quest_id = ""
	
	detail_title_label.text = "No Quest selected"
	detail_description_label.text = ""
	for child in detail_objectives_list.get_children(): child.queue_free()
	for child in detail_log_list.get_children(): child.queue_free()

func _update_detail_view() -> void:
	var quest_data = quest_controller.get_quest_data(_current_selected_quest_id)
	if quest_data.is_empty():
		_clear_detail_view()
		return
	
	var title_string = quest_data.get("title", "FLAWED_TITLE")
	var description_string = quest_data.get("description", "")

	detail_title_label.text = tr(title_string)
	detail_description_label.text = tr(description_string)

	for child in detail_log_list.get_children():
		child.queue_free()
	for log_entry_string in quest_data.get("log_entries", []):
		var log_label = Label.new()
		log_label.text = "- " + tr(log_entry_string)
		log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		log_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		detail_log_list.add_child(log_label)
		
	for child in detail_objectives_list.get_children():
		child.queue_free()

	var active_objectives = quest_controller.get_active_objectives_for_quest(_current_selected_quest_id)
	
	if active_objectives.is_empty():
		var no_obj_label = Label.new()
		no_obj_label.text = "no active objectives."
		no_obj_label.modulate = Color(1, 1, 1, 0.5)
		detail_objectives_list.add_child(no_obj_label)
	else:
		for objective in active_objectives:
			var obj_label = Label.new()
			
			var prefix = "[ ] "
			if objective.status == ObjectiveResource.Status.COMPLETED:
				prefix = "[X] "
			
			var display_text = prefix + tr(objective.description)
			
			var progress_text = ""
			match objective.trigger_type:
				ObjectiveResource.TriggerType.ITEM_COLLECT:
					var required = objective.trigger_params.get("amount", 1)
					if required > 1:
						progress_text = " (%d / %d)" % [objective.current_progress, required]
				ObjectiveResource.TriggerType.KILL:
					if objective.required_progress > 1:
						progress_text = " (%d / %d)" % [objective.current_progress, objective.required_progress]
			
			display_text += progress_text
			obj_label.text = display_text
			detail_objectives_list.add_child(obj_label)
