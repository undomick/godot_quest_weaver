@tool
class_name ParallelOutputPort
extends Resource

## Contains the configuration for a single output of a ParallelNode.

## The name displayed on the port in the GraphEdit.
@export var port_name: String = "Out"

## An optional condition that must be met for this output to activate.
## If null, the output will always activate.
@export var condition: ConditionResource


func _init() -> void:
	condition = QWConstants.ConditionResourceScript.new()
	condition.type = ConditionResource.ConditionType.BOOL

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
