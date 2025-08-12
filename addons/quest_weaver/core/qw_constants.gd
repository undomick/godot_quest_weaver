# res://addons/quest_weaver/core/qw_constants.gd
class_name QWConstants
extends RefCounted

# ==============================================================================
# Script and Scene Paths (Preloads)
# ==============================================================================

# --- Core & Data ---
const Settings = preload("../quest_weaver_settings.tres")
const QWEnums = preload("qw_enums.gd")
const QWNodeSizes = preload("../data/qw_node_sizes.gd")
const QuestGraphResourceScript = preload("../graph/quest_graph_resource.gd")
const DebuggerPluginScript = preload("../debugger/qw_debugger_plugin.gd")
const QuestWeaverDebuggerNode = preload("../debugger/quest_weaver_debugger.gd")

# --- UI: Conditions & Components ---
const QWGraphNode = preload("../ui/editor/qw_graph_node.gd")
const ConditionResourceScript = preload("../ui/conditions/condition_resource.gd")
const ObjectiveResourceScript = preload("../ui/conditions/objective_resource.gd")
const ParallelOutputPortScript = preload("../ui/components/parallel_output_port.gd")
const RandomOutputPortScript = preload("../ui/components/random_output_port.gd")
const SynchronizeInputPortScript = preload("../ui/components/synchronize_input_port.gd")
const SynchronizeOutputPortScript = preload("../ui/components/synchronize_output_port.gd")

# --- UI: Scenes & Editors ---
const MainViewScene = preload("../ui/quest_weaver_editor.tscn")
const ValidatorDockScene = preload("../validation/validator_dock.tscn")
const AutoCompleteLineEditScene = preload("../ui/components/auto_complete_line_edit.tscn")
const QuestFileDialogScene = preload("../ui/dialogs/quest_file_dialog.tscn")
const QuestConfirmationDialogScene = preload("../ui/dialogs/quest_confirmation_dialog.tscn")
const ConditionEditorScene = preload("../ui/conditions/condition_editor.tscn")
const ObjectiveEditorEntryScene = preload("../ui/conditions/objective_editor_entry.tscn")
const ParallelOutputEditorEntryScene = preload("../ui/components/parallel_output_editor_entry.gd")
const OutputEntryScene = preload("../ui/components/parallel_output_editor_entry.tscn")
const RandomOutputEntryScene = preload("../ui/components/random_output_editor_entry.tscn")
const SyncInputEntryScene = preload("../ui/components/synchronize_input_editor_entry.tscn")
const SyncOutputEntryScene = preload("../ui/components/synchronize_output_editor_entry.tscn")
const SyncConditionEditorScene = preload("../ui/conditions/synchronize_condition_editor.tscn")
const SimpleConditionEntryScene = preload("../ui/components/simple_condition_entry.tscn")
const AdvancedConditionEditorScene = preload("../ui/conditions/condition_editor.tscn")

# --- Format & Import/Export ---
const ImportPluginScript = preload("../format/qw_import.gd")
const ExportPluginScript = preload("../format/qw_export.gd")
const QWFormat = preload("../format/qw_format.gd")

# ==============================================================================
# Logic & Runtime Scripts (QuestController)
# ==============================================================================
const ExecutionContext = preload("../logic/execution_context.gd")
const NodeExecutor = preload("../logic/executors/node_executor.gd")
const QuestTimerManager = preload("../logic/managers/quest_timer_manager.gd")
const QuestSyncManager = preload("../logic/managers/quest_sync_manager.gd")
const QuestEventManager = preload("../logic/managers/quest_event_manager.gd")
const QuestStatePersistenceManager = preload("../logic/managers/quest_state_persistence_manager.gd")
const PresentationManager = preload("../logic/managers/presentation_manager.gd")
const QWLogger = preload("../debugger/qw_logger.gd")

# ==============================================================================
# Editor & Plugin Scripts
# ==============================================================================
const QWEditorHistory = preload("../ui/editor/qw_editor_history.gd")
const QWClipboard = preload("../ui/editor/qw_clipboard.gd")
const GRAPH_NODE_CATEGORY = preload("../graph/graph_node_category.tres")
const QuestRegistrar = preload("../editor/quest_registrar.gd")
const LocalizationKeyScanner = preload("../editor/localization_key_scanner.gd")

# ==============================================================================
# String Constants & Identifiers 
# ==============================================================================
const VALIDATOR_DOCK_NAME = "QuestWeaverValidatorDock"
const MODIFIED_SUFFIX = " (*)"
const FILE_EXTENSION = "quest"
const ICON_PATH = "res://addons/quest_weaver/assets/icon.svg"
const RESOURCE_TYPE_NAME = "QuestWeaver.QuestGraph"
const DEBUG_SETTINGS_PATH = "res://addons/quest_weaver/debugger/debug_settings.tres"
const QUEST_CONTEXT_NODE_SCRIPT_PATH = "res://addons/quest_weaver/graph/nodes/quest_context_node_resource.gd"

# ==============================================================================
# Data Structures
# ==============================================================================
# Defines which fields are considered by the Localization Key Scanner.
const TRANSLATABLE_FIELDS = {
	"QuestContextNodeResource": ["quest_title", "quest_description", "log_on_start"],
	"TextNodeResource": ["text_content"],
	"ObjectiveResource": ["description"]
}
