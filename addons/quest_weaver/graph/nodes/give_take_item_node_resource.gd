# res://addons/quest_weaver/graph/nodes/give_take_item_node_resource.gd
@tool
class_name GiveTakeItemNodeResource
extends GraphNodeResource

enum Action { GIVE, TAKE }

@export var item_id: String = ""
@export var amount: int = 1
@export var action: Action = Action.GIVE


func _init() -> void:
	category = "Action" 
	input_ports = ["In"]
	output_ports = ["Success", "Failure"]

func get_editor_summary() -> String:
	# Hole den Namen der Aktion ("Give" oder "Take") aus dem Enum.
	var action_text = Action.keys()[action].capitalize()
	
	var item_info_text: String
	var contains_warning := false

	# Prüfe, ob die Item-ID fehlt.
	if item_id.is_empty():
		# Wenn ja, setze den Warntext und das Flag.
		item_info_text = "%d x (ID Missing)" % amount
		contains_warning = true
	else:
		# Andernfalls, erstelle den normalen Text.
		item_info_text = "%d x '%s'" % [amount, item_id]
	
	# Baue den finalen, zweizeiligen String zusammen.
	var final_summary = "%s\n%s" % [action_text, item_info_text]
	
	# Füge das Präfix hinzu, wenn ein Fehler vorliegt.
	if contains_warning:
		return "[WARN]" + final_summary
	else:
		return final_summary

func execute(controller) -> void:
	pass

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["item_id"] = self.item_id
	data["amount"] = self.amount
	data["action"] = self.action
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.item_id = data.get("item_id", "")
	self.amount = data.get("amount", 1)
	self.action = data.get("action", Action.GIVE)
