class_name CharacterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var title: String = ""
@export var character_class: Enums.CharacterClass = Enums.CharacterClass.NETRUNNER
@export_multiline var backstory: String = ""
@export var passive_name: String = ""
@export var passive_description: String = ""
@export var starter_deck: Array[String] = []
@export var starting_hp: int = 80
@export var starting_energy: int = 3
@export var color_primary: Color = Color.WHITE
@export var color_secondary: Color = Color.GRAY
@export var icon_text: String = ""
