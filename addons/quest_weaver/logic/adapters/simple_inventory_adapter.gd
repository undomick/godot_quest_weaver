# res://addons/quest_weaver/examples/simple_inventory/simple_inventory_adapter.gd
@tool
class_name SimpleInventoryAdapter
extends QuestInventoryAdapterBase

var _inventory_controller = null
var _is_initialized_successfully := false

# This function is called by the QuestController at runtime.
func initialize() -> void:
	# --- START OF FIX ---
	# We need a reference to the scene tree to find our node.
	# We can get it from the QuestWeaverServices singleton.
	var scene_tree = QuestWeaverServices.get_tree()
	if not is_instance_valid(scene_tree):
		push_error("QuestWeaver (SimpleInventoryAdapter): Could not get SceneTree access. Adapter will not function.")
		return
		
	# This adapter expects a node in the scene that belongs to the "inventory_controller" group.
	_inventory_controller = scene_tree.get_first_node_in_group("inventory_controller")
	
	if not is_instance_valid(_inventory_controller):
		push_warning("QuestWeaver (SimpleInventoryAdapter): Could not find a node in group 'inventory_controller' in the scene. This adapter will not function.")
		return
	# --- END OF FIX ---
	
	# Connect to the controller's signal to propagate the update.
	if not _inventory_controller.is_connected("inventory_changed", Callable(self, "_on_inventory_changed")):
		_inventory_controller.inventory_changed.connect(_on_inventory_changed)
	
	_is_initialized_successfully = true
	QuestWeaverServices.logger.log("Inventory", "SimpleInventoryAdapter initialized successfully.")

# Called when the controller signals a change.
func _on_inventory_changed():
	inventory_updated.emit()

# --- ADAPTER METHOD IMPLEMENTATIONS ---
# These functions just pass the call directly to the controller.

func count_item(item_id: String) -> int:
	if not _is_initialized_successfully: return 0
	return _inventory_controller.count_item(item_id)

func check_item(item_id: String, amount: int) -> bool:
	if not _is_initialized_successfully: return false
	return _inventory_controller.check_item(item_id, amount)

func give_item(item_id: String, amount: int) -> void:
	if not _is_initialized_successfully: return
	_inventory_controller.give_item(item_id, amount)

func take_item(item_id: String, amount: int) -> bool:
	if not _is_initialized_successfully: return false
	return _inventory_controller.take_item(item_id, amount)
