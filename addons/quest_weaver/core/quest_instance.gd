# res://addons/quest_weaver/core/quest_instance.gd
class_name QuestInstance
extends RefCounted

## Represents a running instance of a Quest.
## Holds the runtime state (variables, node progress, objective status)
## separate from the static definition (QuestGraphResource).

# --- REFERENCES ---

# The static blueprint defining the logic.
var graph: QuestGraphResource

# --- PERSISTENT STATE (Saved to disk) ---

# The ID of the quest definition (e.g. "kill_rats_01")
var file_id: String = ""

# NEU: Die logische ID aus dem ContextNode (z.B. "main_heart_of_nestor")
var quest_id: String = ""

# Current status of the quest (ACTIVE, COMPLETED, FAILED, etc.)
# Uses QWEnums.QuestState
var current_status: int = 0

# Local variables/parameters for this specific instance.
# Used for parameterized quests (Templates).
# e.g. { "target_amount": 10, "npc_name": "Gondar" }
var variables: Dictionary = {}

# Tracks which nodes are currently "running" (e.g. Timers, EventListeners, TaskNodes).
# Key: node_id (String), Value: Metadata Dictionary (optional, e.g. start time)
var active_node_ids: Dictionary = {}

# Stores the internal state of specific nodes.
# Key: node_id (String), Value: Dictionary (e.g. { "ticks_elapsed": 5 })
var node_states: Dictionary = {}

# Stores the progress of objectives.
# Key: objective_id (String)
# Value: Dictionary { "status": int, "progress": int }
var objective_states: Dictionary = {}

static var _resolver_regex: RegEx = null 

# --- INITIALIZATION ---

func _init(p_file_id: String, p_graph: QuestGraphResource = null):
	self.file_id = p_file_id
	self.graph = p_graph
	# Default to INACTIVE if created fresh
	self.current_status = 0 # QWEnums.QuestState.INACTIVE

# --- NODE STATE MANAGEMENT ---

func set_node_active(node_id: String, is_active: bool, meta: Dictionary = {}) -> void:
	if is_active:
		active_node_ids[node_id] = meta
	else:
		active_node_ids.erase(node_id)

func is_node_active(node_id: String) -> bool:
	return active_node_ids.has(node_id)

func set_node_data(node_id: String, key: String, value: Variant) -> void:
	if not node_states.has(node_id):
		node_states[node_id] = {}
	node_states[node_id][key] = value

func get_node_data(node_id: String, key: String, default: Variant = null) -> Variant:
	if node_states.has(node_id):
		return node_states[node_id].get(key, default)
	return default

func clear_node_state(node_id: String) -> void:
	node_states.erase(node_id)
	active_node_ids.erase(node_id)

# --- OBJECTIVE STATE MANAGEMENT ---

func get_objective_status(objective_id: String) -> int:
	if objective_states.has(objective_id):
		return objective_states[objective_id].get("status", 0) # 0 = INACTIVE
	return 0

func set_objective_status(objective_id: String, status: int) -> void:
	if not objective_states.has(objective_id):
		objective_states[objective_id] = { "status": 0, "progress": 0 }
	
	objective_states[objective_id]["status"] = status

func get_objective_progress(objective_id: String) -> int:
	if objective_states.has(objective_id):
		return objective_states[objective_id].get("progress", 0)
	return 0

func set_objective_progress(objective_id: String, value: int) -> void:
	if not objective_states.has(objective_id):
		objective_states[objective_id] = { "status": 1, "progress": 0 } # Assume ACTIVE if progress updates
	
	objective_states[objective_id]["progress"] = value

func set_objective_description_override(objective_id: String, text: String) -> void:
	if not objective_states.has(objective_id):
		objective_states[objective_id] = { "status": 0, "progress": 0 }
	
	objective_states[objective_id]["description_override"] = text

func get_objective_description(objective_id: String, default_blueprint_text: String) -> String:
	if objective_states.has(objective_id):
		var override = objective_states[objective_id].get("description_override", "")
		if not override.is_empty():
			return override
	return default_blueprint_text

# --- VARIABLE / PARAMETER MANAGEMENT ---

func set_variable(key: String, value: Variant) -> void:
	variables[key] = value

func get_variable(key: String, default: Variant = null) -> Variant:
	return variables.get(key, default)

## Replaces placeholders like "{amount}" in text with actual variable values using RegEx.
func resolve_text(text: String) -> String:
	# Optimization: Early exit if string is empty or has no brackets
	if text.is_empty() or not "{" in text:
		return text
		
	if _resolver_regex == null:
		_resolver_regex = RegEx.new()
		_resolver_regex.compile("\\{(.*?)\\}") # Matches pattern like {variable_name}

	var result = text
	var matches = _resolver_regex.search_all(text)
	
	for regex_match in matches:
		var placeholder = regex_match.get_string(0) # e.g. "{amount}"
		var key = regex_match.get_string(1)         # e.g. "amount"
		
		if variables.has(key):
			# Replace all occurrences of this placeholder with the value
			result = result.replace(placeholder, str(variables[key]))
			
	return result

## Resolves a parameter value.
## If input is a String looking like "{var_name}", it returns the variable value.
## Otherwise returns the input as-is.
func resolve_parameter(input: Variant) -> Variant:
	if input is String:
		if input.begins_with("{") and input.ends_with("}"):
			var key = input.substr(1, input.length() - 2)
			return get_variable(key, input) # Fallback to input string if var missing
	return input

# --- SERIALIZATION ---

func get_save_data() -> Dictionary:
	return {
		"file_id": file_id,
		"quest_id": quest_id,
		"status": current_status,
		"variables": variables.duplicate(),
		"active_node_ids": active_node_ids.duplicate(),
		"node_states": node_states.duplicate(true),
		"objective_states": objective_states.duplicate(true)
	}

func load_save_data(data: Dictionary) -> void:
	self.file_id = data.get("file_id", "")
	self.quest_id = data.get("quest_id", "")
	self.current_status = int(data.get("status", 0))
	self.variables = data.get("variables", {}).duplicate()
	self.active_node_ids = data.get("active_node_ids", {}).duplicate()
	self.node_states = data.get("node_states", {}).duplicate(true)
	self.objective_states = data.get("objective_states", {}).duplicate(true)
