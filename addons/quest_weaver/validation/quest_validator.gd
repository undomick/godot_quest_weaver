# res://addons/quest_weaver/validation/quest_validator.gd
@tool
class_name QuestValidator
extends Node

var _item_registry: Resource
var _quest_registry: Resource


func validate_graph(graph: QuestGraphResource) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	if not is_instance_valid(graph): return results

	_item_registry = _load_resource(QWConstants.Settings.item_registry_path)
	_quest_registry = _load_resource(QWConstants.Settings.quest_registry_path)

	results.append_array(_check_for_orphan_nodes(graph))
	results.append_array(_check_for_cycles(graph))
	
	for node_id in graph.nodes:
		var node: GraphNodeResource = graph.nodes[node_id]
		
		if node is BackdropNodeResource or node is CommentNodeResource: continue
			
		results.append_array(_validate_node_connections(node, graph))
		results.append_array(_validate_node_properties(node))
		
		if node is BranchNodeResource:
			for condition in node.conditions:
				results.append_array(_validate_condition(condition, node_id))
	
	return results

# --- HELPER FUNCTIONS ---

func _validate_node_properties(node: GraphNodeResource) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	var node_id = node.id

	if node is QuestContextNodeResource:
		if node.quest_id.is_empty():
			results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Quest Context: Quest ID is not set.", node_id))
		if node.quest_title.is_empty():
			results.append(ValidationResult.new(ValidationResult.Severity.WARNING, "Quest Context: Quest Title is not set.", node_id))

	elif node is QuestNodeResource:
		var target_id = node.target_quest_id
		if target_id.is_empty():
			results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Quest Manipulator: Target Quest ID is not set.", node_id))
		elif is_instance_valid(_quest_registry) and not target_id in _quest_registry.registered_quest_ids:
			results.append(ValidationResult.new(ValidationResult.Severity.WARNING, "Quest Manipulator: Target Quest ID '%s' not found in the Quest Registry. (Did you update the registry?)" % target_id, node_id))
			
	elif node is TextNodeResource:
		if node.text_content.is_empty():
			results.append(ValidationResult.new(ValidationResult.Severity.INFO, "Quest Text: Text content is empty.", node_id))

	elif node is CompleteObjectiveNodeResource:
		if node.target_objective_id.is_empty():
			results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Complete Objective: Target Objective ID is not set.", node_id))

	elif node is TaskNodeResource:
		if node.objectives.is_empty():
			results.append(ValidationResult.new(ValidationResult.Severity.WARNING, "Task Node has no objectives and will complete immediately.", node_id))
		else:
			for objective in node.objectives:
				if is_instance_valid(objective):
					results.append_array(_validate_objective(objective, node_id))
				else:
					results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Task Node contains an invalid/empty Objective.", node_id))
	
	elif node is EventListenerNodeResource:
		if node.event_name.is_empty():
			results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Event Listener: Event Name is not set.", node_id))
		
	return results

func _validate_objective(objective: ObjectiveResource, node_id: String) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []

	if objective.id.is_empty():
		results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Objective has no ID (should not happen).", node_id))
	if objective.description.is_empty():
		results.append(ValidationResult.new(ValidationResult.Severity.INFO, "Objective in Node '%s' has no description." % node_id, node_id))

	match objective.trigger_type:
		ObjectiveResource.TriggerType.ITEM_COLLECT:
			var item_id = objective.trigger_params.get("item_id", "")
			if item_id.is_empty():
				results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Objective 'Item Collect': No Item ID specified.", node_id))
			elif is_instance_valid(_item_registry) and not _item_registry.definitions.has(item_id):
				results.append(ValidationResult.new(ValidationResult.Severity.WARNING, "Objective 'Item Collect': Item ID '%s' not found in Item Registry." % item_id, node_id))

		ObjectiveResource.TriggerType.KILL:
			var enemy_id = objective.trigger_params.get("enemy_id", "")
			if enemy_id.is_empty():
				results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Objective 'Kill': No Enemy ID specified.", node_id))

		ObjectiveResource.TriggerType.INTERACT:
			var target_path = objective.trigger_params.get("target_path", "")
			if target_path.is_empty():
				results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Objective 'Interact': No Target Path specified.", node_id))
		
		ObjectiveResource.TriggerType.LOCATION_ENTER:
			var loc_id = objective.trigger_params.get("location_id", "")
			if loc_id.is_empty():
				results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Objective 'Location Enter': No Location ID specified.", node_id))
	
	return results

func _validate_condition(condition: ConditionResource, node_id: String) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []

	if not condition is ConditionResource:
		results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "A Condition has lost its specific script...", node_id))
		return results

	match condition.type:
		ConditionResource.ConditionType.CHECK_ITEM:
			var item_id = condition.item_id
			if item_id.is_empty():
				results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Check Item Condition: No Item ID specified.", node_id))
			elif is_instance_valid(_item_registry) and not _item_registry.definitions.has(item_id):
				results.append(ValidationResult.new(ValidationResult.Severity.WARNING, "Check Item Condition: Item ID '%s' not found in registry." % item_id, node_id))
			elif not is_instance_valid(_item_registry):
				results.append(ValidationResult.new(ValidationResult.Severity.INFO, "Could not load Item Registry, ID '%s' could not be checked." % item_id, node_id))

		ConditionResource.ConditionType.CHECK_QUEST_STATUS:
			var target_id = condition.quest_id
			if target_id.is_empty():
				results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Check Quest Status: No target Quest ID specified.", node_id))
			elif is_instance_valid(_quest_registry) and not target_id in _quest_registry.registered_quest_ids:
				results.append(ValidationResult.new(
					ValidationResult.Severity.WARNING, "Check Quest Status: Target Quest ID '%s' not found in Quest Registry." % target_id, node_id))
		
		ConditionResource.ConditionType.COMPOUND:
			if condition.sub_conditions.is_empty():
				results.append(ValidationResult.new(ValidationResult.Severity.INFO, "Compound Condition is empty.", node_id))
			else:
				for sub_condition in condition.sub_conditions:
					if is_instance_valid(sub_condition):
						results.append_array(_validate_condition(sub_condition, node_id))
					else:
						results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Compound Condition contains an invalid entry.", node_id))
		
		_:
			pass

	return results

func _validate_node_connections(node: GraphNodeResource, graph: QuestGraphResource) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	
	if node is BranchNodeResource:
		var true_connected = _is_port_connected(graph, node.id, 0)
		var false_connected = _is_port_connected(graph, node.id, 1)
		if not true_connected and not false_connected:
			results.append(ValidationResult.new(ValidationResult.Severity.WARNING, "Branch: Both 'True' and 'False' outputs are unconnected.", node.id))
		return results

	if node is EndNodeResource or \
		node is RandomNodeResource or \
		node is TimerNodeResource or \
		node is ParallelNodeResource or \
		node is SynchronizeNodeResource or \
		node is GiveTakeItemNodeResource or \
		node is EventListenerNodeResource or \
		node is PlayCutsceneNodeResource:
		return results

	for i in range(node.output_ports.size()):
		if not _is_port_connected(graph, node.id, i):
			var port_name = node.output_ports[i]
			results.append(ValidationResult.new(
				ValidationResult.Severity.ERROR, 
				"Output port '%s' is not connected. The quest flow will stop here." % port_name, 
				node.id
			))
			
	return results

# --- HELFER & ALGORITHMEN ---

func _check_for_orphan_nodes(graph: QuestGraphResource) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	var all_target_nodes: Dictionary = {}

	for connection in graph.connections:
		all_target_nodes[connection.to_node] = true

	for node_id in graph.nodes:
		var node = graph.nodes[node_id]
		
		if not all_target_nodes.has(node_id):
			if not (node is StartNodeResource or node is QuestContextNodeResource):
				results.append(ValidationResult.new(
					ValidationResult.Severity.WARNING,
					"This node is unreachable (no incoming connection).",
					node_id
				))
				
	return results

func _load_resource(path: String) -> Resource:
	if not path.is_empty() and ResourceLoader.exists(path):
		return ResourceLoader.load(path)
	return null

func _is_port_connected(graph: QuestGraphResource, node_id: String, port_index: int) -> bool:
	for connection in graph.connections:
		if connection.from_node == node_id and connection.from_port == port_index:
			return true
	return false

func _check_for_cycles(graph: QuestGraphResource) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	var visited: Dictionary = {}
	var recursion_stack: Dictionary = {}
	
	for node_id in graph.nodes:
		visited[node_id] = false
		recursion_stack[node_id] = false

	for node_id in graph.nodes:
		if not visited[node_id]:
			if _is_cyclic_util(graph, node_id, visited, recursion_stack):
				results.append(ValidationResult.new(
					ValidationResult.Severity.ERROR,
					"An infinite loop was detected starting from this node.",
					node_id
				))
				return results
				
	return results

func _is_cyclic_util(graph: QuestGraphResource, node_id: String, visited: Dictionary, recursion_stack: Dictionary) -> bool:
	visited[node_id] = true
	recursion_stack[node_id] = true
	
	for connection in graph.connections:
		if connection.from_node == node_id:
			var neighbor_id = connection.to_node
			
			if not visited[neighbor_id]:
				if _is_cyclic_util(graph, neighbor_id, visited, recursion_stack):
					return true
			elif recursion_stack[neighbor_id]:
				return true
	
	recursion_stack[node_id] = false
	return false
