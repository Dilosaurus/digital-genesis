extends Control

signal card_chosen(card_id: String)

const CardVisualScene = preload("res://scenes/cards/card_visual.tscn")
const FONT_MEDIEVAL = preload("res://assets/fonts/MedievalSharp.ttf")
const FONT_MONO = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const FONT_LATO = preload("res://assets/fonts/Lato-Regular.ttf")

@onready var title_label: Label = $Panel/TitleLabel
@onready var subtitle_label: Label = $Panel/SubtitleLabel
@onready var card_container: HBoxContainer = $Panel/CardContainer
@onready var skip_button: Button = $Panel/FooterRow/SkipButton
@onready var gold_label: Label = $Panel/FooterRow/GoldDisplay/GoldLabel
@onready var panel: Panel = $Panel

var reward_cards: Array[String] = []

func _ready() -> void:
	skip_button.pressed.connect(_on_skip)
	visible = false

func show_rewards(boss_name: String, card_ids: Array[String]) -> void:
	_populate("ABILITY ABSORBED", "Absorbed: %s — choose a card" % boss_name, card_ids)

func show_card_rewards(card_ids: Array[String]) -> void:
	_populate("CHOOSE A CARD", "Choose a card to add to your deck", card_ids)

func _populate(title: String, subtitle: String, card_ids: Array[String]) -> void:
	reward_cards = []
	for id in card_ids:
		reward_cards.append(id)

	title_label.text = title
	title_label.add_theme_font_override("font", FONT_MEDIEVAL)
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	subtitle_label.text = subtitle
	subtitle_label.add_theme_font_override("font", FONT_LATO)
	subtitle_label.add_theme_font_size_override("font_size", 16)
	subtitle_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.65))

	# Update gold display
	if GameManager.is_run_active():
		gold_label.text = str(GameManager.current_run.gold)
	else:
		gold_label.text = ""
	gold_label.add_theme_font_override("font", FONT_MONO)
	gold_label.add_theme_font_size_override("font_size", 18)
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	# Clear old cards
	for child in card_container.get_children():
		child.queue_free()

	# Create reward card visuals
	for i in card_ids.size():
		var card_node = CardVisualScene.instantiate()
		card_container.add_child(card_node)
		card_node.setup(card_ids[i], i, 99)  # 99 energy = always playable look
		card_node.card_clicked.connect(_on_reward_card_clicked)

	visible = true
	_play_entrance()

func _play_entrance() -> void:
	# Fade the dimmer in, then slide the panel up from slightly below
	var dimmer: ColorRect = $Dimmer
	dimmer.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.position.y += 24.0

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dimmer, "modulate:a", 1.0, 0.18)
	tween.tween_property(panel, "modulate:a", 1.0, 0.22)
	tween.tween_property(panel, "position:y", panel.position.y - 24.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _on_reward_card_clicked(index: int) -> void:
	if index >= 0 and index < reward_cards.size():
		card_chosen.emit(reward_cards[index])
	visible = false

func _on_skip() -> void:
	card_chosen.emit("")
	visible = false
