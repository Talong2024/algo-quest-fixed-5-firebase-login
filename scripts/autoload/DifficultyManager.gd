# DifficultyManager.gd
# Autoload Singleton — Add as "DifficultyManager" in Project > Autoload
# Provides difficulty parameters for every chapter and tier.
extends Node

# ── Tiers ────────────────────────────────────────────────────────────────────
enum Tier { BEGINNER = 0, EASY = 1, NORMAL = 2, HARD = 3, EXPERT = 4 }
const TIER_NAMES := ["Beginner", "Easy", "Normal", "Hard", "Expert"]
signal tier_changed(t: int)
var current_tier: int = Tier.BEGINNER

func set_tier(t: int) -> void:
	current_tier = clamp(t, 0, 4)
	tier_changed.emit(current_tier)

func tier_name() -> String:
	return TIER_NAMES[current_tier]

# ── QUEUE params ─────────────────────────────────────────────────────────────
func queue_params() -> Dictionary:
	match current_tier:
		0: return { "spawn_interval":4.0,"capacity":8,"highlight_front":true,
			"patience":0.0,"penalty":0,"priority_distractor":false,
			"multi_queue":false,"fake_signals":false,"time_limit":0.0,"hints":true }
		1: return { "spawn_interval":3.0,"capacity":6,"highlight_front":true,
			"patience":0.0,"penalty":10,"priority_distractor":false,
			"multi_queue":false,"fake_signals":false,"time_limit":0.0,"hints":true }
		2: return { "spawn_interval":2.5,"capacity":6,"highlight_front":false,
			"patience":8.0,"penalty":15,"priority_distractor":false,
			"multi_queue":false,"fake_signals":false,"time_limit":60.0,"hints":false }
		3: return { "spawn_interval":2.0,"capacity":5,"highlight_front":false,
			"patience":6.0,"penalty":25,"priority_distractor":true,
			"multi_queue":true,"fake_signals":false,"time_limit":60.0,"hints":false }
		_: return { "spawn_interval":1.5,"capacity":4,"highlight_front":false,
			"patience":4.0,"penalty":40,"priority_distractor":true,
			"multi_queue":true,"fake_signals":true,"time_limit":45.0,"hints":false }

# ── STACK params ─────────────────────────────────────────────────────────────
func stack_params() -> Dictionary:
	match current_tier:
		0: return { "max_height":6,"highlight_top":true,"sequence_goal":false,
			"mixed_ops":false,"time_limit":0.0,"multi_stack":false,
			"hidden_items":false,"penalty":0,"hints":true }
		1: return { "max_height":5,"highlight_top":false,"sequence_goal":false,
			"mixed_ops":false,"time_limit":0.0,"multi_stack":false,
			"hidden_items":false,"penalty":10,"hints":true }
		2: return { "max_height":5,"highlight_top":false,"sequence_goal":true,
			"mixed_ops":false,"time_limit":60.0,"multi_stack":false,
			"hidden_items":false,"penalty":15,"hints":false }
		3: return { "max_height":6,"highlight_top":false,"sequence_goal":true,
			"mixed_ops":true,"time_limit":50.0,"multi_stack":false,
			"hidden_items":false,"penalty":25,"hints":false }
		_: return { "max_height":7,"highlight_top":false,"sequence_goal":true,
			"mixed_ops":true,"time_limit":40.0,"multi_stack":true,
			"hidden_items":true,"penalty":40,"hints":false }

# ── LINKED LIST params ───────────────────────────────────────────────────────
func list_params() -> Dictionary:
	match current_tier:
		0: return { "node_count":4,"insert":false,"delete":false,
			"reverse":false,"cycle_detect":false,"multi_list":false,
			"penalty":0,"hints":true }
		1: return { "node_count":5,"insert":true,"delete":false,
			"reverse":false,"cycle_detect":false,"multi_list":false,
			"penalty":10,"hints":true }
		2: return { "node_count":6,"insert":true,"delete":true,
			"reverse":false,"cycle_detect":false,"multi_list":false,
			"penalty":15,"hints":false }
		3: return { "node_count":7,"insert":true,"delete":true,
			"reverse":true,"cycle_detect":false,"multi_list":false,
			"penalty":25,"hints":false }
		_: return { "node_count":8,"insert":true,"delete":true,
			"reverse":true,"cycle_detect":true,"multi_list":true,
			"penalty":40,"hints":false }

# ── TREE params ──────────────────────────────────────────────────────────────
func tree_params() -> Dictionary:
	match current_tier:
		0: return { "guided":true,"node_count":5,"balance_check":false,
			"allow_delete":false,"rebalance_task":false,"penalty":0,"hints":true }
		1: return { "guided":false,"node_count":6,"balance_check":false,
			"allow_delete":false,"rebalance_task":false,"penalty":10,"hints":true }
		2: return { "guided":false,"node_count":8,"balance_check":false,
			"allow_delete":false,"rebalance_task":false,"penalty":15,"hints":false }
		3: return { "guided":false,"node_count":9,"balance_check":true,
			"allow_delete":false,"rebalance_task":false,"penalty":25,"hints":false }
		_: return { "guided":false,"node_count":10,"balance_check":true,
			"allow_delete":true,"rebalance_task":true,"penalty":40,"hints":false }

# ── GRAPH params ─────────────────────────────────────────────────────────────
func graph_params() -> Dictionary:
	match current_tier:
		0: return { "node_count":4,"edge_count":3,"mode":"connect",
			"weighted":false,"dynamic":false,"time_limit":0.0,"penalty":0,"hints":true }
		1: return { "node_count":5,"edge_count":6,"mode":"path",
			"weighted":false,"dynamic":false,"time_limit":0.0,"penalty":10,"hints":true }
		2: return { "node_count":6,"edge_count":8,"mode":"bfs_dfs",
			"weighted":false,"dynamic":false,"time_limit":60.0,"penalty":15,"hints":false }
		3: return { "node_count":7,"edge_count":10,"mode":"dijkstra",
			"weighted":true,"dynamic":false,"time_limit":50.0,"penalty":25,"hints":false }
		_: return { "node_count":8,"edge_count":12,"mode":"dijkstra",
			"weighted":true,"dynamic":true,"time_limit":40.0,"penalty":40,"hints":false }
