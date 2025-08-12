# res://addons/quest_weaver/validation/validation_result.gd
@tool
class_name ValidationResult
extends Resource

enum Severity { ERROR, WARNING, INFO }

var severity: Severity
var message: String
var node_id: String

func _init(p_severity: Severity, p_message: String, p_node_id: String = ""):
	self.severity = p_severity
	self.message = p_message
	self.node_id = p_node_id
