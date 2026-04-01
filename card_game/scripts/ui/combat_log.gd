extends Control

@onready var log_text: RichTextLabel = $Panel/LogText

func add_entry(text: String, color: Color = Color.WHITE) -> void:
	var hex = color.to_html(false)
	log_text.append_text("[color=#%s]%s[/color]\n" % [hex, text])

func add_damage(source: String, target: String, amount: int) -> void:
	add_entry("%s > %s: %d dmg" % [source, target, amount], Color(1, 0.4, 0.3))

func add_block(source: String, amount: int) -> void:
	add_entry("%s: +%d Block" % [source, amount], Color(0.3, 0.6, 1))

func add_heal(source: String, amount: int) -> void:
	add_entry("%s: +%d HP" % [source, amount], Color(0.3, 1, 0.4))

func add_status(text: String) -> void:
	add_entry(text, Color(1, 0.85, 0.3))

func add_system(text: String) -> void:
	add_entry(text, Color(0.6, 0.6, 0.7))
