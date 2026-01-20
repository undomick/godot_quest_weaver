# res://addons/quest_weaver/systems/managers/quest_event_manager.gd
class_name QuestEventManager
extends RefCounted

## Manages global event listeners.
## Stores mapping: EventName -> List of NodeIDs.

var _event_listeners: Dictionary = {} 
var _controller: QuestController

func _init(p_controller: QuestController):
	self._controller = p_controller

func register_listener(listener_node: EventListenerNodeResource):
	var evt = listener_node.event_name
	if not _event_listeners.has(evt):
		_event_listeners[evt] = []
	if not listener_node.id in _event_listeners[evt]:
		_event_listeners[evt].append(listener_node.id)

func unregister_listener(listener_node: EventListenerNodeResource):
	var evt = listener_node.event_name
	if _event_listeners.has(evt):
		_event_listeners[evt].erase(listener_node.id)
		if _event_listeners[evt].is_empty():
			_event_listeners.erase(evt)

func on_global_event(event_name: String, payload: Dictionary):
	if not _event_listeners.has(event_name): return
	
	# Iterate copy to allow modifications during loop
	var listeners = _event_listeners[event_name].duplicate()
	
	for node_id in listeners:
		# 1. Resolve Instance
		var quest_id = _controller.get_quest_id_for_node(node_id)
		var instance: QuestInstance = _controller._active_instances.get(quest_id)
		
		# If instance or node is not active, ignore/cleanup
		if not instance or not instance.is_node_active(node_id):
			# Lazy cleanup: The listener might be stale if cleanup failed elsewhere
			continue
			
		var node_def = _controller._node_definitions.get(node_id)
		if node_def is EventListenerNodeResource:
			# 2. Check Conditions (Instance-aware)
			var condition_passes = true
			if node_def.use_simple_conditions:
				condition_passes = _check_simple_conditions(node_def.simple_conditions, payload)
			else:
				if is_instance_valid(node_def.payload_condition):
					condition_passes = node_def.payload_condition.check(payload, instance)
			
			# 3. Trigger
			if condition_passes:
				if _controller._logger:
					_controller._logger.log("Flow", "Event '%s' triggered listener '%s'." % [event_name, node_id])
				
				if node_def.keep_listening:
					_controller._trigger_next_nodes_from_port(node_def, 0)
				else:
					# One-shot: Remove from my list and complete node
					_event_listeners[event_name].erase(node_id)
					_controller.complete_node(node_def)

func clear():
	_event_listeners.clear()

func remove_listeners_for_quest(nodes_in_quest: Array):
	for evt in _event_listeners.keys():
		var list = _event_listeners[evt]
		for i in range(list.size() - 1, -1, -1):
			if list[i] in nodes_in_quest:
				list.remove_at(i)

# --- Helper for Simple Conditions ---
func _check_simple_conditions(conditions: Array[Dictionary], payload: Dictionary) -> bool:
	if conditions.is_empty(): return true
	for c in conditions:
		var key = c.get("key", "")
		var op = c.get("op", 0)
		var val_str = c.get("value", "")
		
		if key.is_empty(): continue
		if op == 6: # HAS
			if not payload.has(key): return false
			continue
			
		if not payload.has(key):
			if op != 1: return false # Only NOT_EQUALS passes on missing key
			continue
			
		var actual = payload[key]
		var expected = _parse_val(val_str)
		if not _compare(actual, expected, op): return false
	return true

func _compare(a, b, op) -> bool:
	match op:
		0: return a == b
		1: return a != b
		2: return a > b
		3: return a < b
		4: return a >= b
		5: return a <= b
	return false

func _parse_val(t: String):
	if t.is_valid_int(): return t.to_int()
	if t.is_valid_float(): return t.to_float()
	if t.to_lower() == "true": return true
	if t.to_lower() == "false": return false
	return t
