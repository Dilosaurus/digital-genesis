extends Control

signal card_chosen(card_id: String)

const CardVisualScene = preload("res://scenes/cards/card_visual.tscn")

@onready var title_label: Label = $Panel/TitleLabel
@onready var card_container: HBoxContainer = $Panel/CardContainer
@onready var skip_button: Button = $Panel/SkipButton

var reward_cards: Array[String] = []

func _ready() -> void:
	skip_button.pressed.connect(_on_skip)
	visible = false

func show_rewards(boss_name: String, card_ids: Array[String]) -> void:
	reward_cards = []
	for id in card_ids:
		reward_cards.append(id)

	title_label.text = "ABSORBED: %s" % boss_name

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

func _on_reward_card_clicked(index: int) -> void:
	if index >= 0 and index < reward_cards.size():
		card_chosen.emit(reward_cards[index])
	visible = false

func _on_skip() -> void:
	card_chosen.emit("")
	visible = false
