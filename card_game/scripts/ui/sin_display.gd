extends Control

@onready var wrath_label: Label = $WrathLabel
@onready var sloth_label: Label = $SlothLabel
@onready var pride_label: Label = $PrideLabel

func update_sins(wrath: int, sloth: int, pride: int) -> void:
	wrath_label.text = "Wrath: %d/7" % wrath
	wrath_label.add_theme_color_override("font_color", Color(1, 0.3, 0.2) if wrath >= 5 else Color(0.7, 0.5, 0.5))
	sloth_label.text = "Sloth: %d/7" % sloth
	sloth_label.add_theme_color_override("font_color", Color(0.3, 0.5, 1) if sloth >= 5 else Color(0.5, 0.5, 0.7))
	pride_label.text = "Pride: %d/7" % pride
	pride_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2) if pride >= 5 else Color(0.7, 0.7, 0.5))
