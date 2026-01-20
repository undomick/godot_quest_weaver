@tool
class_name ObjectiveResource
extends Resource

# This resource is now a pure blueprint.

enum Status { INACTIVE, ACTIVE, COMPLETED, FAILED }
@export var id: String
@export_multiline var description: String

enum TriggerType { MANUAL, ITEM_COLLECT, LOCATION_ENTER, INTERACT, KILL }
@export var trigger_type: TriggerType = TriggerType.MANUAL
@export var trigger_params: Dictionary = {}

## ONLY for TriggerType.ITEM_COLLECT.
@export var track_progress_since_activation: bool = true

# Defines the target amount (Configuration), NOT the current progress.
@export var required_progress: int = 1

# Runtime Properties
var status: int = 0 
var current_progress: int = 0
var owner_task_node_id: String = ""

func _init():
	trigger_params = {}

# ======================================================
# SERIALIZATION
# ======================================================

func to_dictionary() -> Dictionary:
	return {
		"@script_path": get_script().resource_path,
		"id": self.id, 
		"description": self.description, 
		"trigger_type": self.trigger_type,
		"trigger_params": self.trigger_params, 
		"required_progress": self.required_progress,
		"track_progress_since_activation": self.track_progress_since_activation,
	}

func from_dictionary(data: Dictionary):
	self.id = data.get("id", "")
	self.description = data.get("description", "")
	self.trigger_type = _defensive_load(data, "trigger_type", TriggerType.keys(), TriggerType.MANUAL)
	self.trigger_params = data.get("trigger_params", {})
	self.required_progress = data.get("required_progress", 1)
	self.track_progress_since_activation = data.get("track_progress_since_activation", false)
	
	# Reset runtime vars on load to ensure clean state
	self.status = 0
	self.current_progress = 0
	self.owner_task_node_id = ""

## PRIVATE METHOD: Checks if an integer value is valid for the enum type.
func _defensive_load(data: Dictionary, prop: String, keys: Array, default_val: int) -> int:
	var val = data.get(prop, default_val)
	if val is int and val >= 0 and val < keys.size():
		return val
	return default_val
