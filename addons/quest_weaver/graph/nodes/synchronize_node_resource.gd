# res://addons/quest_weaver/graph/nodes/synchronize_node_resource.gd
@tool
class_name SynchronizeNodeResource
extends GraphNodeResource

enum CompletionMode {
	WAIT_FOR_ALL,
	WAIT_FOR_ANY,
	WAIT_FOR_N_INPUTS
}

@export var completion_mode: CompletionMode = CompletionMode.WAIT_FOR_ALL
@export_range(1, 100) var required_input_count: int = 2
@export var inputs: Array[SynchronizeInputPort] = []
@export var outputs: Array[SynchronizeOutputPort] = []


func _init():
	category = "Flow"
	
	if id.is_empty():
		if inputs.is_empty():
			var in1 = QWConstants.SynchronizeInputPortScript.new(); in1.port_name = "In 1"
			#in1.resource_local_to_scene = true
			var in2 = QWConstants.SynchronizeInputPortScript.new(); in2.port_name = "In 2"
			#in2.resource_local_to_scene = true
			inputs.append(in1); inputs.append(in2)
			
		if outputs.is_empty():
			var out1 = QWConstants.SynchronizeOutputPortScript.new(); out1.port_name = "Out"
			#out1.resource_local_to_scene = true
			outputs.append(out1)
		
	_update_ports_from_data()

func get_editor_summary() -> String:
	match completion_mode:
		CompletionMode.WAIT_FOR_ALL:
			return "Wait for\nALL inputs"
		CompletionMode.WAIT_FOR_ANY:
			return "Wait for\nANY input"
		CompletionMode.WAIT_FOR_N_INPUTS:
			return "Wait for\n%d input(s)" % required_input_count
	return ""

func execute(controller): pass

# ==============================================================================
# EDITOR API - Wird vom SynchronizeNodeEditor aufgerufen
# ==============================================================================

# --- (Inputs) ---

func add_sync_input(_payload: Dictionary):
	var new_input = QWConstants.SynchronizeInputPortScript.new()
	new_input.port_name = "In %d" % (inputs.size() + 1)
	inputs.append(new_input)
	_update_ports_from_data()

func remove_sync_input(payload: Dictionary):
	if payload.has("index") and payload.index >= 0 and payload.index < inputs.size():
		inputs.remove_at(payload.index)
		_update_ports_from_data()

func update_sync_input_name(payload: Dictionary):
	if payload.has("index") and payload.has("new_name"):
		var index = payload.get("index")
		if index >= 0 and index < inputs.size():
			inputs[index].port_name = payload.get("new_name")
			_update_ports_from_data()

# --- (Outputs) ---

func add_sync_output(_payload: Dictionary):
	var new_output = QWConstants.SynchronizeOutputPortScript.new()
	new_output.port_name = "Out %d" % (outputs.size() + 1)
	outputs.append(new_output)
	_update_ports_from_data()

func remove_sync_output(payload: Dictionary):
	if payload.has("index") and payload.index >= 0 and payload.index < outputs.size():
		outputs.remove_at(payload.index)
		_update_ports_from_data()

func update_sync_output_name(payload: Dictionary):
	if payload.has("index") and payload.has("new_name"):
		var index = payload.get("index")
		if index >= 0 and index < outputs.size():
			outputs[index].port_name = payload.get("new_name")
			_update_ports_from_data()

func update_sync_output_condition_property(payload: Dictionary):
	if payload.has("index") and payload.has("property_name") and payload.has("new_value"):
		var index = payload.get("index")
		if index >= 0 and index < outputs.size():
			var port: SynchronizeOutputPort = outputs[index]
			if is_instance_valid(port.condition):
				port.condition.set(payload.get("property_name"), payload.get("new_value"))

func change_sync_output_condition_type(payload: Dictionary):
	if payload.has("index") and payload.has("new_script"):
		var index = payload.get("index")
		if index >= 0 and index < outputs.size():
			var port: SynchronizeOutputPort = outputs[index]
			var new_script = payload.get("new_script")
			if is_instance_valid(new_script):
				port.condition = new_script.new()


func to_dictionary() -> Dictionary:
	var data = super.to_dictionary()
	data["completion_mode"] = self.completion_mode
	data["required_input_count"] = self.required_input_count
	
	var inputs_data = []
	for i in self.inputs:
		if is_instance_valid(i): inputs_data.append(i.to_dictionary())
	data["inputs"] = inputs_data
	
	var outputs_data = []
	for o in self.outputs:
		if is_instance_valid(o): outputs_data.append(o.to_dictionary())
	data["outputs"] = outputs_data
	
	return data

func from_dictionary(data: Dictionary):
	super.from_dictionary(data)
	self.completion_mode = data.get("completion_mode", CompletionMode.WAIT_FOR_ALL)
	self.required_input_count = data.get("required_input_count", 2)
	
	self.inputs.clear()
	for i_data in data.get("inputs", []):
		var script = load(i_data.get("@script_path"))
		if script:
			var new_i = script.new()
			new_i.from_dictionary(i_data)
			self.inputs.append(new_i)
			
	self.outputs.clear()
	for o_data in data.get("outputs", []):
		var script = load(o_data.get("@script_path"))
		if script:
			var new_o = script.new()
			new_o.from_dictionary(o_data)
			self.outputs.append(new_o)

# --- PRIVATE HELPER FUNCTIONS ---

func _update_ports_from_data():
	input_ports.clear()
	for port in inputs:
		if is_instance_valid(port):
			input_ports.append(port.port_name)
	
	output_ports.clear()
	for port in outputs:
		if is_instance_valid(port):
			output_ports.append(port.port_name)

	if required_input_count > inputs.size():
		required_input_count = inputs.size()
	if required_input_count < 1:
		required_input_count = 1
