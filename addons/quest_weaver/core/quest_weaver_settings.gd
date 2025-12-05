# res://addons/quest_weaver/core/quest_weaver_settings.gd
@tool
class_name QuestWeaverSettings
extends Resource

## This resource holds all external paths and settings for the Quest Weaver editor.

@export_group("Integration")
## Quest Objectives might need Inventory Logic. The Inventory Adapter provides a way to let 
## your Inventory talk with Quest Weaver, without rewrite some Quest Weaver itself. 
## Your Adapter has to extend 'QuestInventoryAdapterBase'!
@export_file("*.gd") var inventory_adapter_script: String

## Path to the PresentationRegistry resource. 
## This defines which UI templates (popup styles) are available for the 'Show UI Message' node.
@export_file("*.tres", "res://") var presentation_registry_path: String

## Path to your Item Registry resource.
## This allows the editor to offer auto-completion for Item IDs in various nodes.
@export_file("*.tres", "res://") var item_registry_path: String

@export_group("Automation")
## The folder where you store your '.quest' files. 
## Quest Weaver scans this folder to auto-detect Quest IDs for the 'Quest Registry'.
@export_dir var quest_scan_folder: String

@export_subgroup("Startup")
## A Quest Graph file (.quest) that should be automatically started when the game begins.
## Useful for "Master Quest" that listen for global events.
@export_file("*.quest", "res://") var auto_start_quests: Array[String] = []

@export_subgroup("Localization")
## Optional: Path to a CSV file for localization keys.
## If set, the 'Update Localization Keys' button will scan your quests and append new text keys to this file.
## Localization Keys have to look like this to be considered: FIND_SOME_METAL_QUEST or HELLO_WORLD or QUEST001_MAMA_WILL_HELP
@export_file("*.csv") var localization_csv_path: String

## If you don't plan to customize Quest Weaver, you can ignore those.
@export_group("Internal Data")
## Stores the list of all found Quest IDs (scanned from QuestContext nodes). 
## Used for validation and auto-completion.
@export_file("*.tres") var quest_registry_path: String

## Stores the editor session state (open files, active graph) to restore it on restart.
@export_file("*.tres", "res://") var editor_data_path: String
