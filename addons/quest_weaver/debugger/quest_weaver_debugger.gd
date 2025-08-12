# res://addons/quest_weaver/debugger/quest_weaver_debugger.gd
@tool
class_name QuestWeaverDebugger
extends Node

signal session_started()
signal session_ended()
signal node_activated_in_game(node_id: String)
signal node_completed_in_game(node_id: String)

var debugger_plugin: QuestWeaverDebuggerPlugin

func _init() -> void:
	debugger_plugin = QWConstants.DebuggerPluginScript.new()
	
	debugger_plugin.session_started.connect(session_started.emit)
	debugger_plugin.session_ended.connect(session_ended.emit)
	debugger_plugin.node_activated_in_game.connect(node_activated_in_game.emit)
	debugger_plugin.node_completed_in_game.connect(node_completed_in_game.emit)

func get_plugin_instance() -> QuestWeaverDebuggerPlugin:
	return debugger_plugin
