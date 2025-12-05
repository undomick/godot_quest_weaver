# res://addons/quest_weaver/systems/managers/quest_event_manager.gd
class_name QuestEventManager
extends Object

## Manages the registration and triggering of global quest events.

var _event_listeners: Dictionary = {} # { "event_name": ["node_id_1", "node_id_2"] }
var _controller

func _init(p_controller):
	self._controller = p_controller

## Registers a node that listens for a specific event.
func register_listener(listener_node: EventListenerNodeResource):
	var event_name = listener_node.event_name
	var node_id = listener_node.id

	if not _event_listeners.has(event_name):
		_event_listeners[event_name] = []
		
	if not node_id in _event_listeners[event_name]:
		_event_listeners[event_name].append(node_id)

## Removes a specific listener for an event.
## Required when an EventListener is cancelled (e.g. via Cancel port).
func unregister_listener(listener_node: EventListenerNodeResource):
	var event_name = listener_node.event_name
	var node_id = listener_node.id
	
	if not _event_listeners.has(event_name): return
	
	if node_id in _event_listeners[event_name]:
		_event_listeners[event_name].erase(node_id)
		if _controller._logger:
			_controller._logger.log("System", "Listener '%s' manually unregistered from event '%s'." % [node_id, event_name])
		
	# Cleanup if the array is empty
	if _event_listeners[event_name].is_empty():
		_event_listeners.erase(event_name)

## Called when a global quest event is received.
func on_global_event(event_name: String, payload: Dictionary):
	if not _event_listeners.has(event_name): return
	
	# Iterate backwards or use duplicate to allow removal during iteration
	var listeners_to_trigger = _event_listeners[event_name].duplicate()
	
	for node_id in listeners_to_trigger:
		var node_instance = _controller._active_nodes.get(node_id)
		
		if is_instance_valid(node_instance) and node_instance is EventListenerNodeResource:
			# 1. Check Conditions
			var condition_passes = true
			if node_instance.use_simple_conditions:
				condition_passes = _check_simple_conditions(node_instance.simple_conditions, payload)
			else:
				if is_instance_valid(node_instance.payload_condition):
					condition_passes = node_instance.payload_condition.check(payload)
			
			# 2. Handle Result
			if condition_passes:
				if _controller._logger:
					_controller._logger.log("Flow", "    - Triggering EventListenerNode '%s' (Condition met)." % node_id)
				
				if node_instance.keep_listening:
					# LOOP MODE: Only fire output, do not complete node.
					_controller._trigger_next_nodes_from_port(node_instance, 0)
				else:
					# ONE-SHOT MODE: Remove listener and complete node.
					_event_listeners[event_name].erase(node_id)
					_controller.complete_node(node_instance)
				
			else:
				# Condition failed, do nothing.
				pass
	
	if _event_listeners.has(event_name) and _event_listeners[event_name].is_empty():
		_event_listeners.erase(event_name)

## Clears the internal state.
func clear():
	_event_listeners.clear()

## Removes all listeners belonging to a specific quest.
func remove_listeners_for_quest(nodes_in_quest: Dictionary):
	for event_name in _event_listeners.keys():
		var listeners = _event_listeners[event_name]
		for i in range(listeners.size() - 1, -1, -1):
			var node_id = listeners[i]
			if node_id in nodes_in_quest:
				listeners.remove_at(i)
				if _controller._logger:
					_controller._logger.log("Flow", "De-registered listener '%s' for event '%s'." % [node_id, event_name])

## Returns data for the save system.
func get_save_data() -> Dictionary:
	return _event_listeners.duplicate(true)

## Restores the state from save data.
func load_save_data(data: Dictionary):
	_event_listeners = data

func _check_simple_conditions(conditions: Array[Dictionary], payload: Dictionary) -> bool:
	# If no conditions are defined, the result is always 'true'.
	if conditions.is_empty():
		return true

	for condition in conditions:
		var key = condition.get("key", "")
		var op = condition.get("op", EventListenerNodeResource.SimpleOperator.EQUALS)
		var expected_value_str = condition.get("value", "")
		
		# Ignore empty conditions
		if key.is_empty(): continue 
		
		if op == EventListenerNodeResource.SimpleOperator.HAS:
			if not payload.has(key): return false
			else: continue # HAS condition met, check next.

		if not payload.has(key):
			# If the key is missing, only NOT_EQUALS can be true.
			if op == EventListenerNodeResource.SimpleOperator.NOT_EQUALS:
				continue # Condition met, check next.
			else:
				return false # Condition failed.

		var actual_value = payload[key]
		var expected_value = _parse_string_to_variant(expected_value_str)

		# Perform the actual comparison.
		var result = _compare_values(actual_value, expected_value, op)
		if not result:
			# If a single condition fails, the total result is 'false'.
			return false
			
	# If the loop completes without returning 'false', all conditions are met.
	return true

# Helper functions required by _check_simple_conditions.
func _compare_values(actual: Variant, expected: Variant, op: EventListenerNodeResource.SimpleOperator) -> bool:
	match op:
		EventListenerNodeResource.SimpleOperator.EQUALS: return actual == expected
		EventListenerNodeResource.SimpleOperator.NOT_EQUALS: return actual != expected
		EventListenerNodeResource.SimpleOperator.GREATER_THAN: return actual > expected
		EventListenerNodeResource.SimpleOperator.LESS_THAN: return actual < expected
		EventListenerNodeResource.SimpleOperator.GREATER_OR_EQUAL: return actual >= expected
		EventListenerNodeResource.SimpleOperator.LESS_OR_EQUAL: return actual <= expected
	return false

func _parse_string_to_variant(text: String) -> Variant:
	if text.is_valid_int(): return text.to_int()
	if text.is_valid_float(): return text.to_float()
	if text.to_lower() == "true": return true
	if text.to_lower() == "false": return false
	return text
