class_name CardData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var energy_cost: int = 1
@export var card_type: Enums.CardType = Enums.CardType.ATTACK
@export var target_type: Enums.TargetType = Enums.TargetType.ENEMY
@export var artwork: Texture2D = null
@export var damage: int = 0
@export var block: int = 0
@export var heal: int = 0
@export var draw: int = 0
@export var hits: int = 1
@export var apply_vulnerable: int = 0
@export var apply_weak: int = 0
@export var corruption_gain: int = 0
@export var exhaust: bool = false
@export var gain_strength: int = 0
@export var gain_dexterity: int = 0
@export var upgraded: bool = false
@export var upgrade_id: String = ""
