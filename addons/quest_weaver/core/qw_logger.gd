# res://addons/quest_weaver/core/qw_logger.gd
class_name QWLogger
extends RefCounted

var _active_categories: Dictionary = {}

# This is called once by the QuestController when the game starts.
func initialize():
	var settings: QuestWeaverDebugSettings
	if ResourceLoader.exists(QWConstants.DEBUG_SETTINGS_PATH):
		# Load the resource fresh from disk to get the latest editor settings.
		settings = ResourceLoader.load(QWConstants.DEBUG_SETTINGS_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
		if is_instance_valid(settings):
			_active_categories = settings.active_categories.duplicate()
		else:
			push_warning("QWLogger: Could not load debug_settings.tres. All logs will be printed.")
	else:
		push_warning("QWLogger: Debug settings file not found. All logs will be printed.")

# The main logging function (Info/Debug).
func log(category: String, message: String):
	if _active_categories.get(category, true):
		print("[%s] %s" % [category.to_upper(), message])

# Warnings (Always visible + pushed to Debugger Debugger)
func warn(category: String, message: String):
	push_warning("[%s] %s" % [category.to_upper(), message])

# Errors (Always visible + pushed to Debugger + Pause on Error potential)
func error(category: String, message: String):
	push_error("[%s] %s" % [category.to_upper(), message])
