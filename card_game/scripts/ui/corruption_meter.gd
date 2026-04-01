extends Control

@onready var fill: ColorRect = $BarBG/BarFill
@onready var tier_label: Label = $TierLabel
@onready var value_label: Label = $ValueLabel

const TIER_NAMES = ["PURE", "TAINTED", "CORRUPTED", "DEMONIC"]
const TIER_COLORS = [
	Color(0.3, 0.8, 1.0),    # Pure: cyan
	Color(0.8, 0.6, 0.2),    # Tainted: amber
	Color(0.7, 0.2, 0.8),    # Corrupted: purple
	Color(0.9, 0.1, 0.1),    # Demonic: red
]

func update_corruption(corruption: int, max_corruption: int, tier: int) -> void:
	var pct = clampf(float(corruption) / max_corruption, 0, 1)
	fill.scale.x = pct
	fill.color = TIER_COLORS[clampi(tier, 0, 3)]
	tier_label.text = TIER_NAMES[clampi(tier, 0, 3)]
	tier_label.add_theme_color_override("font_color", TIER_COLORS[clampi(tier, 0, 3)])
	value_label.text = "%d / %d" % [corruption, max_corruption]
