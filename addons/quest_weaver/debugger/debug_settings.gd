# res://addons/quest_weaver/debugger/debug_settings.gd
@tool
class_name QuestWeaverDebugSettings
extends Resource

# A dictionary to hold the state of each debug category.
# Example: {"Flow": true, "Inventory": false}
@export var active_categories: Dictionary = {}
