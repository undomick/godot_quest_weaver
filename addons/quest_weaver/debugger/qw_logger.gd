# res://addons/quest_weaver/debugger/qw_logger.gd
class_name QWLogger
extends Node

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

# The main logging function.
func log(category: String, message: String):
	# Default to 'true' if a category was added but not yet in the settings file.
	if _active_categories.get(category, true):
		print("[%s] %s" % [category.to_upper(), message])

# A dedicated function for warnings, which are always shown.
func warn(category: String, message: String):
	push_warning("[%s] %s" % [category.to_upper(), message])
