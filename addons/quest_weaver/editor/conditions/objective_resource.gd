# res://addons/quest_weaver/editor/conditions/objective_resource.gd
@tool
class_name ObjectiveResource
extends Resource

enum Status { INACTIVE, ACTIVE, COMPLETED, FAILED }
var status: Status = Status.INACTIVE

signal status_changed(new_status: Status)

@export var id: String
@export_multiline var description: String

enum TriggerType { MANUAL, ITEM_COLLECT, LOCATION_ENTER, INTERACT, KILL }
@export var trigger_type: TriggerType = TriggerType.MANUAL
@export var trigger_params: Dictionary = {}

## ONLY for TriggerType.ITEM_COLLECT.
@export var track_progress_since_activation: bool = true

var _item_count_on_activation: int = 0

# --- Variables for Progress ---
@export var required_progress: int = 1
var current_progress: int = 0
var owner_task_node_id: String

func _init():
	trigger_params = {}

func set_status(new_status: Status):
	if status == new_status:
		return
	
	status = new_status
	status_changed.emit(new_status)

# ======================================================
# SERIALIZATION
# ======================================================

func to_dictionary() -> Dictionary:
	return {
		"@script_path": get_script().resource_path,
		"id": self.id, "description": self.description, "trigger_type": self.trigger_type,
		"trigger_params": self.trigger_params, "required_progress": self.required_progress,
		"track_progress_since_activation": self.track_progress_since_activation,
	}

func from_dictionary(data: Dictionary):
	self.id = data.get("id", "")
	self.description = data.get("description", "")
	self.trigger_type = data.get("trigger_type", TriggerType.MANUAL)
	self.trigger_params = data.get("trigger_params", {})
	self.required_progress = data.get("required_progress", 1)
	self.track_progress_since_activation = data.get("track_progress_since_activation", false)
	self.status = Status.INACTIVE
	self.current_progress = 0
	self.owner_task_node_id = ""
	self._item_count_on_activation = 0
