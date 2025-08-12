# res://addons/quest_weaver/graph/nodes/play_cutscene_node_resource.gd
@tool
class_name PlayCutsceneNodeResource
extends GraphNodeResource

## Spielt eine Animation auf einem AnimationPlayer in der Szene ab.

@export var animation_player_path: NodePath
@export var animation_name: StringName
@export var wait_for_completion: bool = true


func _init():
	category = "Action"
	input_ports = ["In"]
	# Wir geben zwei Ausgänge für maximale Flexibilität:
	# "On Start": Feuert sofort, wenn die Animation beginnt.
	# "On Finish": Feuert, wenn die Animation abgeschlossen ist (besonders nützlich, wenn wait_for_completion=false ist).
	output_ports = ["On Start", "On Finish"]

func get_editor_summary() -> String:
	var anim_name_text = str(animation_name) if not str(animation_name).is_empty() else "[WARN]???"
	return "Play:\n%s" % anim_name_text

func execute(controller):
	pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["animation_player_path"] = self.animation_player_path
	data["animation_name"] = self.animation_name
	data["wait_for_completion"] = self.wait_for_completion
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.animation_player_path = data.get("animation_player_path", NodePath())
	self.animation_name = data.get("animation_name", &"")
	self.wait_for_completion = data.get("wait_for_completion", true)
