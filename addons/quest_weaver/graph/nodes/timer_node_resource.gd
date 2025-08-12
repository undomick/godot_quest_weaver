# res://addons/quest_weaver/graph/nodes/timer_node_resource.gd
@tool
class_name TimerNodeResource
extends GraphNodeResource

## Ein nicht-blockierender Timer, der den Questfluss für eine
## bestimmte Dauer fortsetzen kann, während er periodisch Signale aussendet.

@export_range(1, 3600, 1, "suffix:s") var duration: int = 10


func _init():
	category = "Flow" 
	input_ports = ["In"]
	output_ports = ["On Start", "On Tick", "On Finish"]

func get_editor_summary() -> String:
	return "Duration: %d s" % duration

func execute(controller):
	pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["duration"] = self.duration
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.duration = data.get("duration", 10)
