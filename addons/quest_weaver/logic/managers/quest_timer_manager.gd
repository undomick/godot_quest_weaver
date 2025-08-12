# res://addons/quest_weaver/logic/quest_timer_manager.gd
class_name QuestTimerManager
extends Object

## Verwaltet alle aktiven Timer-Knoten für einen QuestController.

var _active_timers: Dictionary = {} # { "node_id": { "timer_node": Timer, "ticks_elapsed": 0, "node_instance": TimerNodeResource } }
var _controller: QuestController

func _init(p_controller: QuestController):
	self._controller = p_controller

## Startet einen neuen Timer basierend auf einer TimerNode-Instanz.
func start_timer(node_instance: TimerNodeResource):
	if _active_timers.has(node_instance.id):
		push_warning("TimerNode '%s' ist bereits aktiv." % node_instance.id)
		return

	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = false
	
	# Wichtig: Das Signal wird mit der _on_timer_tick Methode DIESES Managers verbunden.
	timer.timeout.connect(_on_timer_tick.bind(node_instance.id))
	
	# Wichtig: Der Timer muss ein Kind des Controllers sein, um im Szenenbaum zu existieren.
	_controller.add_child(timer)
	
	_active_timers[node_instance.id] = {
		"timer_node": timer,
		"ticks_elapsed": 0,
		"node_instance": node_instance
	}
	
	# Der Controller muss immer noch den nächsten Knoten auslösen.
	_controller._trigger_next_nodes_from_port(node_instance, 0) # Port 0: "On Start"
	
	timer.start()

## Stoppt und entfernt einen einzelnen, spezifischen Timer anhand seiner Node-ID.
func remove_timer(node_id: String):
	if _active_timers.has(node_id):
		var timer_data = _active_timers[node_id]
		if is_instance_valid(timer_data.timer_node):
			timer_data.timer_node.queue_free()
		_active_timers.erase(node_id)
		return true # Gibt zurück, ob ein Timer entfernt wurde.
	return false

## Wird jede Sekunde von einem laufenden Timer aufgerufen.
func _on_timer_tick(node_id: String):
	if not _active_timers.has(node_id): return

	var timer_data = _active_timers[node_id]
	timer_data.ticks_elapsed += 1
	
	var node_instance: TimerNodeResource = timer_data.node_instance
	print("  - TimerNode '%s' ticked. (%d/%d)" % [node_id, timer_data.ticks_elapsed, node_instance.duration])

	_controller._trigger_next_nodes_from_port(node_instance, 1) # Port 1: "On Tick"

	if timer_data.ticks_elapsed >= node_instance.duration:
		print("  <- TimerNode '%s' finished." % node_id)
		
		_controller._trigger_next_nodes_from_port(node_instance, 2) # Port 2: "On Finish"
		
		var timer_node: Timer = timer_data.timer_node
		timer_node.stop()
		timer_node.queue_free()
		
		_active_timers.erase(node_id)
		
		# Der Controller ist immer noch für den Status der Knoten verantwortlich.
		node_instance.status = GraphNodeResource.Status.COMPLETED
		_controller._completed_nodes[node_instance.id] = node_instance
		if _controller._active_nodes.has(node_instance.id):
			_controller._active_nodes.erase(node_instance.id)

## Bereinigt alle laufenden Timer. Wird beim Neuladen/Zurücksetzen benötigt.
func clear_all_timers():
	for timer_data in _active_timers.values():
		if is_instance_valid(timer_data.timer_node):
			timer_data.timer_node.queue_free()
	_active_timers.clear()

## Gibt die Daten der aktiven Timer für das Speichersystem zurück.
func get_save_data() -> Dictionary:
	var timers_to_save = {}
	for node_id in _active_timers:
		timers_to_save[node_id] = _active_timers[node_id].ticks_elapsed
	return timers_to_save

## Stellt die Timer aus den Speicherdaten wieder her.
func load_save_data(timers_to_load: Dictionary, active_nodes: Dictionary):
	for node_id in timers_to_load:
		var node_instance = active_nodes.get(node_id)
		if is_instance_valid(node_instance) and node_instance is TimerNodeResource:
			start_timer(node_instance) # Ruft unsere eigene Methode auf
			if _active_timers.has(node_id):
				_active_timers[node_id].ticks_elapsed = timers_to_load[node_id]
