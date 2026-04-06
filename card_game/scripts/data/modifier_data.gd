class_name ModifierData
extends Resource

@export var id: String = ""
@export var stat: Enums.Stat = Enums.Stat.DAMAGE
@export var operation: Enums.ModOp = Enums.ModOp.FLAT_ADD
@export var value: float = 0.0

# Lifecycle
@export var lifecycle: Enums.ModLifecycle = Enums.ModLifecycle.PERMANENT
@export var duration: int = -1  # Turns remaining. -1 = not applicable.

# Conditions (empty/default = always active)
@export var required_card_tags: Array[int] = []  # Enums.CardTag values
@export var required_card_type: int = -1         # -1 = any, otherwise Enums.CardType
@export var only_vs_vulnerable: bool = false
@export var only_when_hp_below_pct: float = -1.0 # -1 = disabled, 0.5 = below 50% HP

# Source tracking (set at runtime, not exported)
var source_type: String = ""  # "equipment", "gem", "relic", "skill_tree", "status"
var source_id: String = ""    # specific item/node ID

func stamped(p_source_type: String, p_source_id: String) -> ModifierData:
	var copy = duplicate()
	copy.source_type = p_source_type
	copy.source_id = p_source_id
	return copy
