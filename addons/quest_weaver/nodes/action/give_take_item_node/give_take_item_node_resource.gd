# res://addons/quest_weaver/nodes/action/give_take_item_node/give_take_item_node_resource.gd
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
	var action_text = Action.keys()[action].capitalize()
	
	var item_info_text: String
	var contains_warning := false

	# Check if the Item ID is missing.
	if item_id.is_empty():
		item_info_text = "%d x (ID Missing)" % amount
		contains_warning = true
	else:
		item_info_text = "%d x '%s'" % [amount, item_id]
	
	var final_summary = "%s\n%s" % [action_text, item_info_text]
	
	# Add the warning prefix if necessary to trigger red styling in the graph node.
	if contains_warning:
		return "[WARN]" + final_summary
	else:
		return final_summary

func get_description() -> String:
	return "Adds or removes specific items from the player's inventory via the Inventory Adapter."

func get_icon() -> Texture2D:
	return preload("res://addons/quest_weaver/assets/icons/give_take.svg")

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

func _validate(_context: Dictionary) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	
	if item_id.is_empty():
		results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Give/Take Item: No Item ID specified.", id))
	if amount <= 0:
		results.append(ValidationResult.new(ValidationResult.Severity.WARNING, "Give/Take Item: Amount must be greater than 0.", id))
		
	return results
