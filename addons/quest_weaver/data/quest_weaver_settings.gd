# res://addons/quest_weaver/data/quest_weaver_settings.gd
@tool
class_name QuestWeaverSettings
extends Resource

## This resource holds all external paths and settings for the Quest Weaver editor.

@export_group("Integration")
## Quest Objectives might need Inventory Logic. The Inventory Adapter provides a way to let 
## your Inventory talk with Quest Weaver, without rewrite some Quest Weaver itself. 
## Your Adapter has to extend 'QuestInventoryAdapterBase'!
@export_file("*.gd") var inventory_adapter_script: String

@export_file("*.tres", "res://") var presentation_registry_path: String
## You can drag and drop your Item Registry resource here via the Inspector.
## the registry is a collection of all your item-definitions in the game. 
@export_file("*.tres", "res://") var item_registry_path: String


@export_group("Automation")
## Set a Folder where you store all your Quests. This helps Quest Weaver to anticipate things like Quest-IDs
@export_dir var quest_scan_folder: String

@export_subgroup("Localization")
## Set a path to a *.csv, for exporting all new Localization Keys.
## Push the "Update Localization Keys"-Button
## this is optional! it's just a helper tool, if you like to localize your game.
## Localization Keys have to look like this to be considered: FIND_SOME_METAL_QUEST or HELLO_WORLD or QUEST001_MAMA_WILL_HELP
@export_file("*.csv") var localization_csv_path: String


## If you don't plan to customize Quest Weaver, you can ignore those.
@export_group("Quest Weaver Tools")

@export_subgroup("Registrate Quest Graph Nodes")
## GraphNode Registry
@export_file("*.tres") var node_type_registry_path: String

@export_subgroup("Quest IDs")
## Resource which stores all Quest-IDs from Quest Context Nodes
@export_file("*.tres") var quest_registry_path: String

@export_subgroup("Automatic Quest Registration (on startup)")
## Path to the resource that stores the editor's session data (open files, etc.)
@export_file("*.tres", "res://") var editor_data_path: String
