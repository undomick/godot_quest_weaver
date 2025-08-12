# res://addons/quest_weaver/ui/editor/qw_editor_utils.gd
@tool
class_name QWEditorUtils
extends RefCounted

static var _cached_item_ids: Array[String] = []
static var _cached_quest_ids: Array[String] = []
static var _item_registry_loaded := false
static var _quest_registry_loaded := false

## Clears the internal cache, forcing a reload from disk on the next call.
static func clear_cache() -> void:
	_cached_item_ids.clear()
	_cached_quest_ids.clear()
	_item_registry_loaded = false
	_quest_registry_loaded = false

## Populates an AutoCompleteLineEdit with all item IDs from the registry.
static func populate_item_completer(completer: AutoCompleteLineEdit):
	# Step 1: Check if we have already loaded the data.
	if not _item_registry_loaded:
		_load_item_registry_data()
	
	# Step 2: Use the cached data.
	completer.set_items(_cached_item_ids)

## Populates an AutoCompleteLineEdit with all quest IDs from the registry.
static func populate_quest_id_completer(completer: AutoCompleteLineEdit):
	# Step 1: Check if we have already loaded the data.
	if not _quest_registry_loaded:
		_load_quest_registry_data()
	
	# Step 2: Use the cached data.
	completer.set_items(_cached_quest_ids)

# Internal function to load item data and fill the cache.
static func _load_item_registry_data() -> void:
	_cached_item_ids.clear()
	_item_registry_loaded = true # Mark as loaded even if it fails, to prevent retries.

	if not is_instance_valid(QWConstants.Settings) or QWConstants.Settings.item_registry_path.is_empty():
		_cached_item_ids.append("!Error: Item Registry path not set!")
		return
		
	var item_registry = ResourceLoader.load(QWConstants.Settings.item_registry_path)
	if not is_instance_valid(item_registry):
		_cached_item_ids.append("!Error: Could not load Item Registry!")
		return
		
	var all_ids: Array[String] = []
	if "item_definitions" in item_registry and item_registry.item_definitions is Array:
		for definition in item_registry.item_definitions:
			if is_instance_valid(definition) and not definition.id.is_empty():
				all_ids.append(definition.id)
	
	if all_ids.is_empty():
		_cached_item_ids.append("(Registry is empty)")
	else:
		_cached_item_ids = all_ids

# Internal function to load quest data and fill the cache.
static func _load_quest_registry_data() -> void:
	_cached_quest_ids.clear()
	_quest_registry_loaded = true # Mark as loaded even if it fails.

	if QWConstants.Settings.quest_registry_path.is_empty() or not ResourceLoader.exists(QWConstants.Settings.quest_registry_path):
		_cached_quest_ids.append("!Error: Quest Registry path not set!")
		return
	
	var registry: QuestRegistry = ResourceLoader.load(QWConstants.Settings.quest_registry_path, "QuestRegistry", ResourceLoader.CACHE_MODE_REPLACE)
	
	if is_instance_valid(registry):
		if registry.registered_quest_ids.is_empty():
			_cached_quest_ids.append("(No Quests found. Save a graph with an ID)")
		else:
			_cached_quest_ids = registry.registered_quest_ids
	else:
		_cached_quest_ids.append("!Error: Could not load Quest Registry!")
