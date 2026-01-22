# res://addons/quest_weaver/core/qw_condition_logic.gd
class_name QWConditionLogic
extends RefCounted

## Central logic for comparing values.
## Maps to ConditionResource.Operator and EventListenerNodeResource.SimpleOperator (Indices 0-5).
enum Op { EQUALS, NOT_EQUALS, GREATER_THAN, LESS_THAN, GREATER_OR_EQUAL, LESS_OR_EQUAL }

static func compare(val_a: Variant, val_b: Variant, op: int) -> bool:
	if val_a == null: return false 

	# Numeric safety: Allow comparison between int and float
	if typeof(val_a) != typeof(val_b):
		var is_num_a = (val_a is float or val_a is int)
		var is_num_b = (val_b is float or val_b is int)
		if not (is_num_a and is_num_b):
			return false

	match op:
		Op.EQUALS: return val_a == val_b
		Op.NOT_EQUALS: return val_a != val_b
		Op.GREATER_THAN: return val_a > val_b
		Op.LESS_THAN: return val_a < val_b
		Op.GREATER_OR_EQUAL: return val_a >= val_b
		Op.LESS_OR_EQUAL: return val_a <= val_b
		
	return false

static func parse_string_to_variant(text: String) -> Variant:
	if text.is_valid_int(): return text.to_int()
	if text.is_valid_float(): return text.to_float()
	if text.to_lower() == "true": return true
	if text.to_lower() == "false": return false
	return text
