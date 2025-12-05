# res://addons/quest_weaver/core/qw_constants.gd
class_name QWConstants
extends RefCounted

# ==============================================================================
# Settings & Resources
# ==============================================================================
const Settings = preload("../quest_weaver_settings.tres")
const GRAPH_NODE_CATEGORY = preload("../assets/graph_node_category.tres")

# ==============================================================================
# UI Scenes (.tscn) - Diese müssen wir preloaden, um sie zu instanziieren
# ==============================================================================
const MainViewScene = preload("../editor/quest_weaver_editor.tscn")
const ValidatorDockScene = preload("../editor/validation/validator_dock.tscn")
const AutoCompleteLineEditScene = preload("../editor/components/auto_complete_line_edit.tscn")
const QuestFileDialogScene = preload("../editor/dialogs/quest_file_dialog.tscn")
const QuestConfirmationDialogScene = preload("../editor/dialogs/quest_confirmation_dialog.tscn")
const ConditionEditorScene = preload("../editor/conditions/condition_editor.tscn")
const ObjectiveEditorEntryScene = preload("../editor/conditions/objective_editor_entry.tscn")

# Editor Scenes for specific components
const OutputEntryScene = preload("../editor/components/parallel_output_editor_entry.tscn")
const RandomOutputEntryScene = preload("../editor/components/random_output_editor_entry.tscn")
const SyncInputEntryScene = preload("../editor/components/synchronize_input_editor_entry.tscn")
const SyncOutputEntryScene = preload("../editor/components/synchronize_output_editor_entry.tscn")
const SyncConditionEditorScene = preload("../editor/conditions/synchronize_condition_editor.tscn")
const SimpleConditionEntryScene = preload("../editor/components/simple_condition_entry.tscn")
const AdvancedConditionEditorScene = preload("../editor/conditions/condition_editor.tscn")

# ==============================================================================
# Strings, Paths & Identifiers
# ==============================================================================
const VALIDATOR_DOCK_NAME = "QuestWeaverValidatorDock"
const MODIFIED_SUFFIX = " (*)"
const FILE_EXTENSION = "quest"
const ICON_PATH = "res://addons/quest_weaver/assets/icons/icon.svg"
const RESOURCE_TYPE_NAME = "QuestWeaver.QuestGraph"
const DEBUG_SETTINGS_PATH = "res://addons/quest_weaver/core/debug_settings.tres"
const QUEST_CONTEXT_NODE_SCRIPT_PATH = "res://addons/quest_weaver/nodes/logic/quest_context_node/quest_context_node_resource.gd"

# ==============================================================================
# Data Structures
# ==============================================================================
const TRANSLATABLE_FIELDS = {
	"QuestContextNodeResource": ["quest_title", "quest_description", "log_on_start"],
	"TextNodeResource": ["text_content"],
	"ObjectiveResource": ["description"]
}
