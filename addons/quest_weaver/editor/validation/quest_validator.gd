# res://addons/quest_weaver/editor/validation/quest_validator.gd
@tool
class_name QuestValidator
extends Node

var _item_registry: Resource
var _quest_registry: Resource


func validate_graph(graph: QuestGraphResource) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	if not is_instance_valid(graph): return results

	_item_registry = _load_resource(QWConstants.get_settings().item_registry_path)
	_quest_registry = _load_resource(QWConstants.get_settings().quest_registry_path)

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
	# We pack the registries into a context dictionary to pass it to the node.
	var context = {
		"item_registry": _item_registry,
		"quest_registry": _quest_registry
	}
	
	# Delegate the validation logic to the node resource itself.
	var results = node._validate(context)
	
	# BranchNode is special because it contains Conditions which are sub-resources.
	# We handle them here to avoid circular dependency issues in the resource script for now,
	# or keep it centralized as they are complex logic containers.
	if node is BranchNodeResource:
		for condition in node.conditions:
			results.append_array(_validate_condition(condition, node.id))
			
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
			
			elif is_instance_valid(_item_registry):
				if _item_registry.has_method("find"):
					if not _item_registry.find(item_id):
						results.append(ValidationResult.new(ValidationResult.Severity.WARNING, "Item ID '%s' not found in registry." % item_id, node_id))

		ConditionResource.ConditionType.CHECK_QUEST_STATUS:
			var target_id = condition.quest_id
			if target_id.is_empty():
				results.append(ValidationResult.new(ValidationResult.Severity.ERROR, "Check Quest Status: No target Quest ID specified.", node_id))
			
			elif is_instance_valid(_quest_registry) and not _quest_registry.quest_path_map.has(target_id):
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
				ValidationResult.Severity.WARNING, 
				"Output port '%s' is unconnected. Flow stops here." % port_name, 
				node.id
			))
			
	return results

# --- HELFER & ALGORITHMEN ---

func _check_for_orphan_nodes(graph: QuestGraphResource) -> Array[ValidationResult]:
	var results: Array[ValidationResult] = []
	var all_target_nodes: Dictionary = {}

	# Collect all nodes that are targeted by a connection
	for connection in graph.connections:
		all_target_nodes[connection.to_node] = true

	for node_id in graph.nodes:
		var node = graph.nodes[node_id]
		
		# If the node has an incoming connection, it is reachable.
		if all_target_nodes.has(node_id):
			continue

		# --- EXCEPTIONS: Nodes that are allowed to be orphans ---
		
		# 1. Entry Points: Nodes that start execution logic
		if node is StartNodeResource or node is QuestContextNodeResource:
			continue
			
		# 2. Visual Helpers: Nodes that don't participate in logic flow
		if node is BackdropNodeResource or node is CommentNodeResource:
			continue
			
		# 3. Generic Check: If a node physically has no input ports, 
		#    it cannot receive a connection, so warning is redundant.
		if node.input_ports.is_empty():
			continue

		# If none of the exceptions apply, issue a warning.
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
