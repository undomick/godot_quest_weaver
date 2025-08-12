# res://addons/quest_weaver/logic/quest_event_manager.gd
class_name QuestEventManager
extends Object

## Verwaltet die Registrierung und Auslösung von globalen Quest-Events.

var _event_listeners: Dictionary = {} # { "event_name": ["node_id_1", "node_id_2"] }
var _controller

func _init(p_controller):
	self._controller = p_controller

## Registriert einen Knoten, der auf ein bestimmtes Event lauscht.
func register_listener(listener_node: EventListenerNodeResource):
	var event_name = listener_node.event_name
	var node_id = listener_node.id

	if not _event_listeners.has(event_name):
		_event_listeners[event_name] = []
		
	if not node_id in _event_listeners[event_name]:
		_event_listeners[event_name].append(node_id)

## Wird aufgerufen, wenn ein globales Quest-Event empfangen wird.
func on_global_event(event_name: String, payload: Dictionary):
	print("[QuestEventManager] Global event received: '%s'" % event_name)
	
	if not _event_listeners.has(event_name): return
	
	var listeners_to_trigger = _event_listeners[event_name].duplicate()
	
	for node_id in listeners_to_trigger:
		var node_instance = _controller._active_nodes.get(node_id)
		
		if is_instance_valid(node_instance) and node_instance is EventListenerNodeResource:
			var condition_passes = true # Standardmäßig annehmen, dass die Bedingung erfüllt ist
			
			if node_instance.use_simple_conditions:
				# Prüfe die neue, einfache Key-Value-Liste
				condition_passes = _check_simple_conditions(node_instance.simple_conditions, payload)
			else:
				# Prüfe die bestehende, fortgeschrittene ConditionResource
				if is_instance_valid(node_instance.payload_condition):
					condition_passes = node_instance.payload_condition.check(payload)
			
			if condition_passes:
				print("    - Triggering EventListenerNode '%s' (Condition met)." % node_id)
				_event_listeners[event_name].erase(node_id) # Nur bei Erfolg entfernen
				_controller.complete_node(node_instance)
			else:
				print("    - EventListenerNode '%s' received event, but payload condition failed." % node_id)
	
	if _event_listeners.has(event_name) and _event_listeners[event_name].is_empty():
		_event_listeners.erase(event_name)

## Bereinigt den Zustand.
func clear():
	_event_listeners.clear()

## Entfernt alle Listener, die zu einer bestimmten Quest gehören.
func remove_listeners_for_quest(nodes_in_quest: Dictionary):
	for event_name in _event_listeners.keys():
		var listeners = _event_listeners[event_name]
		for i in range(listeners.size() - 1, -1, -1):
			var node_id = listeners[i]
			if node_id in nodes_in_quest:
				listeners.remove_at(i)
				print("  - [EventManager] De-registered listener '%s' for event '%s'." % [node_id, event_name])

## Gibt die Daten für das Speichersystem zurück.
func get_save_data() -> Dictionary:
	return _event_listeners.duplicate(true)

## Stellt den Zustand aus Speicherdaten wieder her.
func load_save_data(data: Dictionary):
	_event_listeners = data

func _check_simple_conditions(conditions: Array[Dictionary], payload: Dictionary) -> bool:
	# Wenn keine Bedingungen definiert sind, ist das Ergebnis immer 'true'.
	if conditions.is_empty():
		return true

	for condition in conditions:
		var key = condition.get("key", "")
		var op = condition.get("op", EventListenerNodeResource.SimpleOperator.EQUALS)
		var expected_value_str = condition.get("value", "")
		
		# Wenn der Schlüssel leer ist oder in der Payload fehlt (außer bei NOT_EQUALS),
		# ist die Bedingung nicht erfüllt. Die HAS-Operation ist eine Ausnahme.
		if key.is_empty(): continue # Ignoriere leere Bedingungen
		
		if op == EventListenerNodeResource.SimpleOperator.HAS:
			if not payload.has(key): return false
			else: continue # HAS-Bedingung erfüllt, prüfe die nächste.

		if not payload.has(key):
			# Wenn der Key nicht da ist, kann nur NOT_EQUALS wahr sein.
			if op == EventListenerNodeResource.SimpleOperator.NOT_EQUALS:
				continue # Bedingung erfüllt, prüfe die nächste.
			else:
				return false # Bedingung nicht erfüllt.

		var actual_value = payload[key]
		var expected_value = _parse_string_to_variant(expected_value_str)

		# Führe den eigentlichen Vergleich durch.
		var result = _compare_values(actual_value, expected_value, op)
		if not result:
			# Wenn eine einzige Bedingung fehlschlägt, ist das Gesamtergebnis 'false'.
			return false
			
	# Wenn die Schleife durchläuft, ohne 'false' zurückzugeben, sind alle Bedingungen erfüllt.
	return true

# Diese Hilfsfunktionen werden von _check_simple_conditions benötigt.
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
