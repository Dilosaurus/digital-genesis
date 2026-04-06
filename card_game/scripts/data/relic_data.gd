class_name RelicData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: int = 0  # 0=common, 1=uncommon, 2=rare
@export var icon: Texture2D = null

# Effect keys — checked by RelicSystem
@export var start_combat_strength: int = 0
@export var start_combat_dexterity: int = 0
@export var start_combat_block: int = 0
@export var bonus_draw: int = 0
@export var bonus_max_energy: int = 0
@export var bonus_max_hp: int = 0
@export var heal_on_combat_end: int = 0
@export var corruption_resistance: int = 0
@export var auto_revive: bool = false     # Auto-revive once per floor when entering Death's Door
