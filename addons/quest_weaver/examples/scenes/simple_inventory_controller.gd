# res://addons/quest_weaver/examples/simple_inventory/simple_inventory_controller.gd
extends Node

# Signal that the adapter will listen to.
signal inventory_changed

# Our simple in-memory inventory.
# Format: { "item_id": quantity }
var _inventory: Dictionary = {
	"health_potion": 3,
	"mana_potion": 5,
	"gold_coin": 100
}

# Prints the current inventory to the console.
func print_inventory():
	print("\n--- Simple Inventory Content ---")
	for item_id in _inventory:
		print("  - %s: %d" % [item_id, _inventory[item_id]])
	print("----------------------------\n")

# --- PUBLIC API FOR THE ADAPTER ---

func count_item(item_id: String) -> int:
	return _inventory.get(item_id, 0)

func check_item(item_id: String, amount: int) -> bool:
	return count_item(item_id) >= amount

func give_item(item_id: String, amount: int) -> void:
	var current_amount = count_item(item_id)
	_inventory[item_id] = current_amount + amount
	print("[SimpleInventoryController] Gave %d x '%s'. New total: %d" % [amount, item_id, _inventory[item_id]])
	inventory_changed.emit()

func take_item(item_id: String, amount: int) -> bool:
	if not check_item(item_id, amount):
		print("[SimpleInventoryController] FAILED to take %d x '%s'. Not enough items." % [amount, item_id])
		return false
	
	_inventory[item_id] -= amount
	print("[SimpleInventoryController] Took %d x '%s'. New total: %d" % [amount, item_id, _inventory[item_id]])
	inventory_changed.emit()
	return true
