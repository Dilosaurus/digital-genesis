class_name SkillTreeData
extends Resource

# Unique identifier used to look up this tree
@export var id: String = ""

# Human-readable name shown in the UI header
@export var display_name: String = ""

# All nodes that make up this tree.
# Populated programmatically by SkillTreeSystem._create_default_trees().
var nodes: Array[SkillNodeData] = []
