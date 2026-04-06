class_name EquipmentData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var slot: Enums.EquipSlot = Enums.EquipSlot.ACCESSORY
@export var rarity: int = 0  # 0=common, 1=uncommon, 2=rare
@export var icon: Texture2D = null
@export var modifiers: Array[ModifierData] = []
