# res://addons/quest_weaver/ui/components/synchronize_output_port.gd
@tool
class_name SynchronizeOutputPort
extends Resource

## Defines a single, conditional output of a SynchronizeNode.

@export var port_name: String = "Out"

## Optional: A condition that is checked AFTER synchronization.
## If null, the output will always activate.
@export var condition: ConditionResource


func _init() -> void:
	# A new SynchronizeOutputPort always starts with a condition
	# that checks the synchronizer's state by default.
	condition = QWConstants.ConditionResourceScript.new()
	condition.type = ConditionResource.ConditionType.CHECK_SYNCHRONIZER


func to_dictionary() -> Dictionary:
	var data: Dictionary = {
		"@script_path": get_script().get_path(),
		"port_name": port_name
	}
	
	if is_instance_valid(condition):
		data["condition"] = condition.to_dictionary()
		
	return data


func from_dictionary(data: Dictionary) -> void:
	port_name = data.get("port_name", "Out")
	
	var condition_data: Variant = data.get("condition")
	if condition_data is Dictionary:
		var script: Script = load(condition_data.get("@script_path"))
		if is_instance_valid(script):
			condition = script.new()
			condition.from_dictionary(condition_data)
