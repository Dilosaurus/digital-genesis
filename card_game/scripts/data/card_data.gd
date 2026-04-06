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
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var character_class: int = -1   # -1 = shared, 0-4 = character-exclusive
@export var tags: Array[int] = []       # Enums.CardTag values
@export var cooldown_max: int = 0       # Turns of cooldown after playing (0 = none)
@export var gem_sockets: int = 0        # 0, 1, or 2 sockets for gems

# --- Party / co-op effect fields ---
@export var party_heal: int = 0          # Heal ALL players this amount
@export var party_draw: int = 0          # ALL players draw this many extra cards next turn
@export var party_damage: int = 0        # ALL players take this damage (self-harm mechanic)
@export var share_block: bool = false     # Split own block evenly among all players
@export var transfer_mana: int = 0       # Transfer this much mana to target player
@export var mark_target: bool = false     # Mark enemy: +50% damage from all sources this turn

# --- Revival fields (Phase 3 Stream D) ---
@export var revive_ally: bool = false   # Revive a downed/dead ally
@export var revive_hp: int = 15         # HP to revive with
