# res://addons/quest_weaver/graph/nodes/set_variable_node_resource.gd
@tool
class_name SetVariableNodeResource
extends GraphNodeResource

# Der Name der Variable im GameState, die wir setzen wollen.
@export var variable_name: String = ""

# Der Wert, den wir setzen wollen, als String gespeichert für den Editor.
@export var value_to_set_string: String = ""

# Optional: Ein Operator, um Werte zu modifizieren statt nur zu überschreiben.
enum Operator { SET, ADD, SUBTRACT, MULTIPLY, DIVIDE, TOGGLE }
@export var operator: Operator = Operator.SET


func _init():
	category = "Logic" 
	input_ports = ["In"]
	output_ports = ["Out"]

func get_editor_summary() -> String:
	var op_text: String
	match operator:
		Operator.SET: op_text = "="
		Operator.ADD: op_text = "+="
		Operator.SUBTRACT: op_text = "-="
		Operator.MULTIPLY: op_text = "*="
		Operator.DIVIDE: op_text = "/="
		Operator.TOGGLE: op_text = "~="
	
	var var_name_text = variable_name if not variable_name.is_empty() else "???"
	
	# Für TOGGLE brauchen wir keinen Wert anzuzeigen, das macht es sauberer.
	if operator == Operator.TOGGLE:
		return "%s %s" % [var_name_text, op_text]
	
	var value_text = value_to_set_string if not value_to_set_string.is_empty() else "???"
	return "%s %s %s" % [var_name_text, op_text, value_text]

func execute(controller):
	pass

# Die gleiche Hilfsfunktion wie in der Condition, um den String zu parsen.
func _parse_string_to_variant(text: String) -> Variant:
	var parsed_value: Variant = text
	if text.is_valid_int():
		parsed_value = text.to_int()
	elif text.is_valid_float():
		parsed_value = text.to_float()
	elif text.to_lower() == "true":
		parsed_value = true
	elif text.to_lower() == "false":
		parsed_value = false
	return parsed_value

func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["variable_name"] = self.variable_name
	data["value_to_set_string"] = self.value_to_set_string
	data["operator"] = self.operator
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.variable_name = data.get("variable_name", "")
	self.value_to_set_string = data.get("value_to_set_string", "")
	self.operator = data.get("operator", Operator.SET)
