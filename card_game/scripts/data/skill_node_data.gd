class_name SkillNodeData
extends Resource

# Unique identifier for this node within the tree
@export var id: String = ""

# Display name shown in the UI
@export var display_name: String = ""

# Tooltip description shown on hover
@export var description: String = ""

# Tier determines prerequisite depth and layout row
# 0 = starting, 1 = mid, 2 = advanced, 3 = capstone
@export var tier: int = 0

# Skill points required to unlock
@export var cost: int = 1

# IDs of nodes that must be unlocked before this one
@export var prerequisites: Array[String] = []

# Modifier effects granted when this node is unlocked.
# These are resolved as PERMANENT lifecycle modifiers during combat.
# Stored as plain Dictionaries because typed Array[Resource] is
# hard to populate in code without .tres files.
# Each dict matches ModifierSpec fields (see SkillTreeSystem).
var modifier_specs: Array = []

# Visual position hint for the UI layout (x=column, y=tier row)
@export var position: Vector2 = Vector2.ZERO
