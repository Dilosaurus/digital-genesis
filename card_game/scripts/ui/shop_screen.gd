extends Control

signal shop_closed

# ── Prices ──────────────────────────────────────────────────────────────────
const CARD_PRICE        := 50
const RELIC_PRICE_COMMON   := 150
const RELIC_PRICE_UNCOMMON := 250
const RELIC_PRICE_RARE     := 400
const UPGRADE_PRICE     := 100
const BASE_REMOVE_PRICE := 75
const REMOVE_PRICE_STEP := 25   # Price increase per removal already done this run

# ── State ─────────────────────────────────────────────────────────────────────
var shop_cards:  Array[String] = []
var shop_relics: Array[String] = []

# ── Lifecycle ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	visible = false

func open_shop() -> void:
	_generate_shop()
	_build_ui()
	visible = true

# ── Generation ────────────────────────────────────────────────────────────────
func _generate_shop() -> void:
	shop_cards.clear()
	shop_relics.clear()

	# Cards: 5 random non-curse non-upgraded cards
	var all_cards = GameManager.card_database.keys()
	var candidates: Array[String] = []
	for cid in all_cards:
		var cd = GameManager.get_card_data(cid)
		if cd and not cd.id.begins_with("curse_") and not cd.upgraded and cd.energy_cost <= 3:
			candidates.append(cid)
	candidates.shuffle()
	for i in mini(5, candidates.size()):
		shop_cards.append(candidates[i])

	# Relics: 2 random relics not already owned
	var run = GameManager.current_run
	var relic_rewards = RelicSystem.get_random_relic_reward(run.relics if run else [], 2)
	for rid in relic_rewards:
		shop_relics.append(rid)

# ── UI Build ──────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	for child in $Panel/ItemContainer.get_children():
		child.queue_free()

	var run = GameManager.current_run
	$Panel/GoldLabel.text = "Gold: %d" % run.gold

	_build_section_label("── Cards ──────────────────────")
	_build_card_items(run)

	_build_section_label("── Relics ─────────────────────")
	_build_relic_items(run)

	_build_section_label("── Services ───────────────────")
	_build_service_items(run)

	_build_leave_button()

func _build_section_label(text: String) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	lbl.custom_minimum_size = Vector2(380, 24)
	$Panel/ItemContainer.add_child(lbl)

func _build_card_items(run: RunState) -> void:
	for cid in shop_cards:
		var cd = GameManager.get_card_data(cid)
		if not cd:
			continue

		var btn = Button.new()
		var type_str = _get_card_type_str(cd)
		var energy_str = "[%d]" % cd.energy_cost if cd.energy_cost >= 0 else "[X]"
		btn.text = "%s %s  (%s) — %dg" % [energy_str, cd.display_name, type_str, CARD_PRICE]
		btn.custom_minimum_size = Vector2(380, 38)
		btn.disabled = run.gold < CARD_PRICE

		# Tint button to reflect card type
		var col = _get_card_color(cd)
		btn.add_theme_color_override("font_color", col)

		btn.pressed.connect(_buy_card.bind(cid))
		$Panel/ItemContainer.add_child(btn)

func _build_relic_items(run: RunState) -> void:
	if shop_relics.is_empty():
		var lbl = Label.new()
		lbl.text = "  (no relics available)"
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		lbl.custom_minimum_size = Vector2(380, 30)
		$Panel/ItemContainer.add_child(lbl)
		return

	for rid in shop_relics:
		var relic = RelicSystem.get_relic(rid)
		if not relic:
			continue

		var price = _relic_price(relic.rarity)
		var rarity_str = _rarity_str(relic.rarity)
		var btn = Button.new()
		btn.text = "%s  [%s] — %dg" % [relic.display_name, rarity_str, price]
		btn.tooltip_text = relic.description
		btn.custom_minimum_size = Vector2(380, 38)
		btn.disabled = run.gold < price or rid in run.relics

		var rarity_col = _rarity_color(relic.rarity)
		btn.add_theme_color_override("font_color", rarity_col)

		btn.pressed.connect(_buy_relic.bind(rid))
		$Panel/ItemContainer.add_child(btn)

func _build_service_items(run: RunState) -> void:
	var remove_price = BASE_REMOVE_PRICE + run.remove_count * REMOVE_PRICE_STEP

	# Card removal
	var remove_btn = Button.new()
	remove_btn.text = "Remove a card — %dg  (removes random card from deck)" % remove_price
	remove_btn.custom_minimum_size = Vector2(380, 38)
	remove_btn.disabled = run.gold < remove_price or run.deck.size() <= 5
	remove_btn.pressed.connect(_remove_card)
	$Panel/ItemContainer.add_child(remove_btn)

	# Card upgrade service
	var upgradeable_count = _count_upgradeable(run)
	var upgrade_btn = Button.new()
	upgrade_btn.text = "Upgrade a random card — %dg" % UPGRADE_PRICE
	upgrade_btn.custom_minimum_size = Vector2(380, 38)
	upgrade_btn.disabled = run.gold < UPGRADE_PRICE or upgradeable_count == 0
	if upgradeable_count == 0:
		upgrade_btn.text += "  (no upgradeable cards)"
	upgrade_btn.pressed.connect(_upgrade_card)
	$Panel/ItemContainer.add_child(upgrade_btn)

func _build_leave_button() -> void:
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(380, 8)
	$Panel/ItemContainer.add_child(spacer)

	var leave_btn = Button.new()
	leave_btn.text = "Leave Shop"
	leave_btn.custom_minimum_size = Vector2(380, 40)
	leave_btn.pressed.connect(func():
		visible = false
		shop_closed.emit()
	)
	$Panel/ItemContainer.add_child(leave_btn)

# ── Purchase handlers ──────────────────────────────────────────────────────────
func _buy_card(card_id: String) -> void:
	var run = GameManager.current_run
	if run.gold < CARD_PRICE:
		return
	run.gold -= CARD_PRICE
	run.add_card(card_id)
	shop_cards.erase(card_id)
	_build_ui()

func _buy_relic(relic_id: String) -> void:
	var run = GameManager.current_run
	var relic = RelicSystem.get_relic(relic_id)
	if not relic:
		return
	var price = _relic_price(relic.rarity)
	if run.gold < price or relic_id in run.relics:
		return
	run.gold -= price
	run.add_relic(relic_id)
	shop_relics.erase(relic_id)
	_build_ui()

func _remove_card() -> void:
	var run = GameManager.current_run
	var remove_price = BASE_REMOVE_PRICE + run.remove_count * REMOVE_PRICE_STEP
	if run.gold < remove_price or run.deck.size() <= 5:
		return
	run.gold -= remove_price
	run.deck.remove_at(randi() % run.deck.size())
	run.remove_count += 1
	_build_ui()

func _upgrade_card() -> void:
	var run = GameManager.current_run
	if run.gold < UPGRADE_PRICE:
		return
	var upgradeable: Array[int] = []
	for i in run.deck.size():
		var cd = GameManager.get_card_data(run.deck[i])
		if cd and cd.upgrade_id != "":
			upgradeable.append(i)
	if upgradeable.is_empty():
		return
	run.gold -= UPGRADE_PRICE
	var idx = upgradeable[randi() % upgradeable.size()]
	var old_cd = GameManager.get_card_data(run.deck[idx])
	if old_cd and old_cd.upgrade_id != "":
		run.deck[idx] = old_cd.upgrade_id
	_build_ui()

# ── Utilities ─────────────────────────────────────────────────────────────────
func _relic_price(rarity: int) -> int:
	match rarity:
		0: return RELIC_PRICE_COMMON
		1: return RELIC_PRICE_UNCOMMON
		2: return RELIC_PRICE_RARE
		_: return RELIC_PRICE_COMMON

func _rarity_str(rarity: int) -> String:
	match rarity:
		0: return "Common"
		1: return "Uncommon"
		2: return "Rare"
		_: return "Common"

func _rarity_color(rarity: int) -> Color:
	match rarity:
		0: return Color(0.85, 0.85, 0.85)        # white-grey
		1: return Color(0.25, 0.85, 0.50)        # green
		2: return Color(0.95, 0.80, 0.20)        # gold
		_: return Color(0.85, 0.85, 0.85)

func _get_card_type_str(cd: CardData) -> String:
	match cd.card_type:
		Enums.CardType.ATTACK:  return "Attack"
		Enums.CardType.SKILL:   return "Skill"
		Enums.CardType.POWER:   return "Power"
		Enums.CardType.STATUS:  return "Status"
		Enums.CardType.CURSE:   return "Curse"
	return "Card"

func _get_card_color(cd: CardData) -> Color:
	match cd.card_type:
		Enums.CardType.ATTACK:  return Color(0.90, 0.30, 0.30)
		Enums.CardType.SKILL:   return Color(0.30, 0.60, 0.90)
		Enums.CardType.POWER:   return Color(0.75, 0.45, 0.95)
		Enums.CardType.CURSE:   return Color(0.45, 0.45, 0.45)
		Enums.CardType.STATUS:  return Color(0.55, 0.55, 0.55)
	return Color(0.90, 0.90, 0.90)

func _count_upgradeable(run: RunState) -> int:
	var count = 0
	for cid in run.deck:
		var cd = GameManager.get_card_data(cid)
		if cd and cd.upgrade_id != "":
			count += 1
	return count
