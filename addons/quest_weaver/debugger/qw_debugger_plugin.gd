# res://addons/quest_weaver/debugger/qw_debugger_plugin.gd
@tool
class_name QuestWeaverDebuggerPlugin
extends EditorDebuggerPlugin

signal session_started()
signal session_ended()
signal node_activated_in_game(node_id: String)
signal node_completed_in_game(node_id: String)

func has_capture(capture: String) -> bool:
	return capture == "quest_weaver"

func _capture(message: String, data: Array, _session_id: int):
	print("[DEBUGGER-PLUGIN] Message received from game! Message: '%s'" % message)

	match message:
		"session_started":
			session_started.emit()
		"session_ended":
			session_ended.emit()
		"node_activated":
			if not data.is_empty() and data[0] is String:
				node_activated_in_game.emit(data[0])
		"node_completed":
			if not data.is_empty() and data[0] is String:
				node_completed_in_game.emit(data[0])
