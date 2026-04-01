extends Control

signal shop_closed

var shop_cards: Array[String] = []
var card_price: int = 50
var remove_price: int = 75

func _ready() -> void:
	visible = false

func open_shop() -> void:
	_generate_shop()
	_build_ui()
	visible = true

func _generate_shop() -> void:
	shop_cards.clear()
	var all_cards = GameManager.card_database.keys()
	var candidates: Array[String] = []
	for cid in all_cards:
		var cd = GameManager.get_card_data(cid)
		if cd and not cd.id.begins_with("curse_") and not cd.upgraded and cd.energy_cost <= 3:
			candidates.append(cid)
	candidates.shuffle()
	for i in mini(5, candidates.size()):
		shop_cards.append(candidates[i])

func _build_ui() -> void:
	for child in $Panel/ItemContainer.get_children():
		child.queue_free()

	var run = GameManager.current_run
	$Panel/GoldLabel.text = "Gold: %d" % run.gold

	for cid in shop_cards:
		var cd = GameManager.get_card_data(cid)
		if not cd:
			continue
		var btn = Button.new()
		btn.text = "%s — %dg" % [cd.display_name, card_price]
		btn.custom_minimum_size = Vector2(380, 35)
		btn.disabled = run.gold < card_price
		btn.pressed.connect(_buy_card.bind(cid))
		$Panel/ItemContainer.add_child(btn)

	# Card removal option
	var remove_btn = Button.new()
	remove_btn.text = "Remove a card — %dg" % remove_price
	remove_btn.custom_minimum_size = Vector2(380, 35)
	remove_btn.disabled = run.gold < remove_price or run.deck.size() <= 5
	remove_btn.pressed.connect(_remove_card)
	$Panel/ItemContainer.add_child(remove_btn)

	var leave_btn = Button.new()
	leave_btn.text = "Leave Shop"
	leave_btn.custom_minimum_size = Vector2(380, 35)
	leave_btn.pressed.connect(func():
		visible = false
		shop_closed.emit()
	)
	$Panel/ItemContainer.add_child(leave_btn)

func _buy_card(card_id: String) -> void:
	var run = GameManager.current_run
	if run.gold >= card_price:
		run.gold -= card_price
		run.add_card(card_id)
		shop_cards.erase(card_id)
		_build_ui()

func _remove_card(_card_id_unused: String = "") -> void:
	var run = GameManager.current_run
	if run.gold < remove_price or run.deck.size() <= 5:
		return
	var idx = randi() % run.deck.size()
	run.deck.remove_at(idx)
	run.gold -= remove_price
	_build_ui()
