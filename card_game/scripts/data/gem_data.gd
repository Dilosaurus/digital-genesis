class_name GemData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: int = 0  # 0=common, 1=uncommon, 2=rare
@export var icon: Texture2D = null

# Modifiers applied when the socketed card is played (CARD_PLAY lifecycle)
@export var on_play_modifiers: Array[ModifierData] = []
