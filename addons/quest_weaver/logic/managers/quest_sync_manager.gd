# res://addons/quest_weaver/logic/quest_sync_manager.gd
class_name QuestSyncManager
extends Object

## Verwaltet den Zustand aller aktiven SynchronizeNode-Instanzen.

var _active_synchronizers: Dictionary = {} # { "sync_node_id": { "inputs_received": [bool], "instance": SynchronizeNodeResource} }
var _controller: QuestController

func _init(p_controller: QuestController):
	self._controller = p_controller

## Wird aufgerufen, wenn ein Quest-Pfad bei einem Synchronizer ankommt.
func handle_input(sync_node_def: SynchronizeNodeResource, received_on_port: int) -> void:
	var node_id = sync_node_def.id
	print("Synchronizer '%s' received input on port %d." % [node_id, received_on_port])

	if not _active_synchronizers.has(node_id):
		var input_count = sync_node_def.inputs.size()
		_active_synchronizers[node_id] = {
			"inputs_received": [false] * input_count,
			"instance": sync_node_def.duplicate(true)
		}
		var instance = _active_synchronizers[node_id].instance
		instance.status = GraphNodeResource.Status.ACTIVE
		_controller._active_nodes[node_id] = instance

	var sync_state = _active_synchronizers[node_id]
	if received_on_port >= 0 and received_on_port < sync_state.inputs_received.size():
		if not sync_state.inputs_received[received_on_port]:
			sync_state.inputs_received[received_on_port] = true
	else:
		push_warning("Synchronizer '%s' received signal on invalid port %d." % [node_id, received_on_port])

	var should_complete = false
	match sync_node_def.completion_mode:
		SynchronizeNodeResource.CompletionMode.WAIT_FOR_ALL:
			if not false in sync_state.inputs_received: should_complete = true
		SynchronizeNodeResource.CompletionMode.WAIT_FOR_ANY:
			# Feuert nur beim allerersten Eingangssignal.
			if sync_state.inputs_received.count(true) == 1: should_complete = true
		SynchronizeNodeResource.CompletionMode.WAIT_FOR_N_INPUTS:
			var received_count = sync_state.inputs_received.count(true)
			if received_count >= sync_node_def.required_input_count: should_complete = true

	if should_complete:
		print("  - Synchronizer '%s' met its completion condition." % node_id)
		var instance_to_complete = sync_state.instance
		
		# Entferne aus den Listen, bevor Ausgänge gefeuert werden.
		remove_synchronizer(node_id)
		
		# Feuere die Ausgänge mit dem finalen Zustand.
		_fire_outputs(instance_to_complete, sync_state)
		
		# Markiere den Knoten als logisch abgeschlossen.
		_controller._mark_node_as_logically_complete(instance_to_complete)

	else:
		print("  - Synchronizer '%s' is waiting. Current state: %s" % [node_id, sync_state.inputs_received])

## Feuert die Ausgänge eines abgeschlossenen Synchronizers.
func _fire_outputs(sync_node_instance: SynchronizeNodeResource, final_sync_state: Dictionary) -> void:
	var connections = _controller._node_connections.get(sync_node_instance.id, [])

	for i in range(sync_node_instance.outputs.size()):
		var output_port_info: SynchronizeOutputPort = sync_node_instance.outputs[i]
		
		var should_fire = true
		if is_instance_valid(output_port_info.condition):
			# ERWEITERUNG: Wir übergeben den vollen ExecutionContext, damit Bedingungen
			# wie CHECK_ITEM oder CHECK_VARIABLE funktionieren. Für CHECK_SYNCHRONIZER
			# fügen wir die relevanten Daten zum Kontext-Dictionary hinzu.
			var context_for_check
			if output_port_info.condition.type == ConditionResource.ConditionType.CHECK_SYNCHRONIZER:
				# Für reine Synchronizer-Checks reicht ein Dictionary.
				context_for_check = {
					"sync_inputs_received_array": final_sync_state.inputs_received,
				}
			else:
				# Für alle anderen Checks (Item, Variable etc.) den vollen Kontext übergeben.
				context_for_check = _controller._execution_context
			
			should_fire = output_port_info.condition.check(context_for_check)
		
		if should_fire:
			for connection in connections:
				if connection.from_port == i:
					var next_node_def = _controller._node_definitions.get(connection.to_node)
					if next_node_def:
						_controller._activate_node(next_node_def, connection.to_port)
					break

## Setzt den Zustand aus Speicherdaten wieder her.
func load_save_data(data: Dictionary):
	_active_synchronizers = data.duplicate(true)

## Gibt die Daten für das Speichersystem zurück.
func get_save_data() -> Dictionary:
	return _active_synchronizers.duplicate(true)

## Bereinigt den Zustand.
func clear():
	_active_synchronizers.clear()

## Entfernt einen spezifischen Synchronizer, z.B. wenn eine Quest fehlschlägt.
func remove_synchronizer(node_id: String):
	if _active_synchronizers.has(node_id):
		_active_synchronizers.erase(node_id)

func get_active_synchronizer_ids() -> Array:
	return _active_synchronizers.keys()
