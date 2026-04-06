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
var shop_equipment: Array[String] = []
var shop_gems: Array[String] = []

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var item_container: VBoxContainer = $Panel/ScrollContainer/ItemContainer
@onready var gold_label: Label = $Panel/HeaderPanel/HeaderRow/GoldRow/GoldLabel

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
	shop_equipment.clear()
	shop_gems.clear()

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

	# Equipment: 2 random
	var equip_rewards = EquipmentSystem.get_random_equipment_reward(run.equipment if run else {}, 2)
	for eid in equip_rewards:
		shop_equipment.append(eid)

	# Gems: 3 random
	var gem_rewards = GemSystem.get_random_gem_reward(3)
	for gid in gem_rewards:
		shop_gems.append(gid)

# ── UI Build ──────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	for child in item_container.get_children():
		child.queue_free()

	var run = GameManager.current_run
	gold_label.text = "%dg  |  %d Souls  |  %d Crystals  |  %d Essence" % [run.gold, run.souls, run.crystals, run.corruption_essence]
	gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	_build_section_label("CARDS", Color(0.90, 0.30, 0.30, 1.00))
	_build_card_items(run)

	_build_section_label("RELICS", Color(1.00, 0.75, 0.15, 1.00))
	_build_relic_items(run)

	_build_section_label("EQUIPMENT", Color(0.40, 0.75, 1.00, 1.00))
	_build_equipment_items(run)

	_build_section_label("GEMS", Color(0.35, 0.80, 0.45, 1.00))
	_build_gem_items(run)

	_build_section_label("SERVICES", Color(0.55, 0.60, 0.72, 1.00))
	_build_service_items(run)

	_build_leave_button()

func _build_section_label(text: String, accent_color: Color) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 2)
	margin.custom_minimum_size = Vector2(520, 28)

	var lbl = Label.new()
	lbl.text = "  %s" % text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", accent_color)

	# Bottom border rule via a child separator
	var vbox := VBoxContainer.new()
	vbox.add_child(lbl)
	var sep := HSeparator.new()
	sep.add_theme_color_override("separation_color", Color(accent_color.r, accent_color.g, accent_color.b, 0.35))
	vbox.add_child(sep)

	margin.add_child(vbox)
	item_container.add_child(margin)

func _build_card_items(run: RunState) -> void:
	for cid in shop_cards:
		var cd = GameManager.get_card_data(cid)
		if not cd:
			continue

		var btn = Button.new()
		var type_str = _get_card_type_str(cd)
		var energy_str = "[%d]" % cd.energy_cost if cd.energy_cost >= 0 else "[X]"
		btn.text = "  %s  %s  (%s)     %dg  " % [energy_str, cd.display_name, type_str, CARD_PRICE]
		btn.custom_minimum_size = Vector2(520, 40)
		btn.disabled = run.gold < CARD_PRICE

		var col = _get_card_color(cd)
		btn.add_theme_color_override("font_color", col)

		btn.pressed.connect(_buy_card.bind(cid))
		item_container.add_child(btn)

func _build_relic_items(run: RunState) -> void:
	if shop_relics.is_empty():
		var lbl = Label.new()
		lbl.text = "  (no relics available)"
		lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.52, 1.0))
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.custom_minimum_size = Vector2(520, 30)
		item_container.add_child(lbl)
		return

	for rid in shop_relics:
		var relic = RelicSystem.get_relic(rid)
		if not relic:
			continue

		var price = _relic_price(relic.rarity)
		var rarity_str = _rarity_str(relic.rarity)
		var btn = Button.new()
		btn.text = "  %s  [%s]     %dg  " % [relic.display_name, rarity_str, price]
		btn.tooltip_text = relic.description
		btn.custom_minimum_size = Vector2(520, 40)
		btn.disabled = run.gold < price or rid in run.relics

		btn.add_theme_color_override("font_color", _rarity_color(relic.rarity))
		btn.pressed.connect(_buy_relic.bind(rid))
		item_container.add_child(btn)

func _build_equipment_items(run: RunState) -> void:
	if shop_equipment.is_empty():
		var lbl = Label.new()
		lbl.text = "  (no equipment available)"
		lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.52, 1.0))
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.custom_minimum_size = Vector2(520, 30)
		item_container.add_child(lbl)
		return

	for eid in shop_equipment:
		var equip = EquipmentSystem.get_equipment(eid)
		if not equip:
			continue
		var price = EquipmentSystem.get_price(equip.rarity)
		var slot_name = _equip_slot_name(equip.slot)
		var btn = Button.new()
		btn.text = "  %s  [%s]  (%s)     %dg  " % [equip.display_name, slot_name, _rarity_str(equip.rarity), price]
		btn.tooltip_text = equip.description
		btn.custom_minimum_size = Vector2(520, 40)
		btn.disabled = run.gold < price
		btn.add_theme_color_override("font_color", _rarity_color(equip.rarity))
		btn.pressed.connect(_buy_equipment.bind(eid))
		item_container.add_child(btn)

func _build_gem_items(run: RunState) -> void:
	if shop_gems.is_empty():
		var lbl = Label.new()
		lbl.text = "  (no gems available)"
		lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.52, 1.0))
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.custom_minimum_size = Vector2(520, 30)
		item_container.add_child(lbl)
		return

	for gid in shop_gems:
		var gem = GemSystem.get_gem(gid)
		if not gem:
			continue
		var price = GemSystem.get_price(gem.rarity)
		var btn = Button.new()
		btn.text = "  %s  (%s)     %dg  " % [gem.display_name, _rarity_str(gem.rarity), price]
		btn.tooltip_text = gem.description
		btn.custom_minimum_size = Vector2(520, 40)
		btn.disabled = run.gold < price
		btn.add_theme_color_override("font_color", _rarity_color(gem.rarity))
		btn.pressed.connect(_buy_gem.bind(gid))
		item_container.add_child(btn)

func _build_service_items(run: RunState) -> void:
	var remove_price = BASE_REMOVE_PRICE + run.remove_count * REMOVE_PRICE_STEP

	var remove_btn = Button.new()
	remove_btn.text = "  Remove a card from deck     %dg  " % remove_price
	remove_btn.custom_minimum_size = Vector2(520, 40)
	remove_btn.disabled = run.gold < remove_price or run.deck.size() <= 5
	remove_btn.pressed.connect(_remove_card)
	item_container.add_child(remove_btn)

	var upgradeable_count = _count_upgradeable(run)
	var upgrade_btn = Button.new()
	upgrade_btn.text = "  Upgrade a random card     %dg  " % UPGRADE_PRICE
	if upgradeable_count == 0:
		upgrade_btn.text = "  Upgrade a random card  (none upgradeable)     %dg  " % UPGRADE_PRICE
	upgrade_btn.custom_minimum_size = Vector2(520, 40)
	upgrade_btn.disabled = run.gold < UPGRADE_PRICE or upgradeable_count == 0
	upgrade_btn.pressed.connect(_upgrade_card)
	item_container.add_child(upgrade_btn)

func _build_leave_button() -> void:
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(520, 10)
	item_container.add_child(spacer)

	var sep := HSeparator.new()
	item_container.add_child(sep)

	var leave_btn = Button.new()
	leave_btn.text = "Leave Shop"
	leave_btn.custom_minimum_size = Vector2(520, 44)
	# Give it a distinct danger-red tint to differentiate from buy buttons
	leave_btn.add_theme_color_override("font_color", Color(1.00, 0.70, 0.70, 1.00))
	leave_btn.pressed.connect(func():
		visible = false
		shop_closed.emit()
	)
	item_container.add_child(leave_btn)

	# Bottom padding
	var pad = Control.new()
	pad.custom_minimum_size = Vector2(520, 8)
	item_container.add_child(pad)

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

func _buy_equipment(equip_id: String) -> void:
	var run = GameManager.current_run
	var equip = EquipmentSystem.get_equipment(equip_id)
	if not equip:
		return
	var price = EquipmentSystem.get_price(equip.rarity)
	if run.gold < price:
		return
	run.gold -= price
	EquipmentSystem.equip(run, equip_id)
	shop_equipment.erase(equip_id)
	_build_ui()

func _buy_gem(gem_id: String) -> void:
	var run = GameManager.current_run
	var gem = GemSystem.get_gem(gem_id)
	if not gem:
		return
	var price = GemSystem.get_price(gem.rarity)
	if run.gold < price:
		return
	run.gold -= price
	run.gems.append(gem_id)
	shop_gems.erase(gem_id)
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
		0: return Color(0.75, 0.75, 0.78)   # silver-grey
		1: return Color(0.35, 0.80, 0.45)   # green
		2: return Color(1.00, 0.75, 0.15)   # gold
		_: return Color(0.75, 0.75, 0.78)

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
		Enums.CardType.ATTACK:  return Color(0.90, 0.40, 0.40)
		Enums.CardType.SKILL:   return Color(0.40, 0.70, 1.00)
		Enums.CardType.POWER:   return Color(0.95, 0.80, 0.20)
		Enums.CardType.CURSE:   return Color(0.60, 0.45, 0.70)
		Enums.CardType.STATUS:  return Color(0.55, 0.55, 0.60)
	return Color(0.90, 0.90, 0.90)

func _equip_slot_name(slot: int) -> String:
	match slot:
		Enums.EquipSlot.HEAD: return "Head"
		Enums.EquipSlot.CHEST: return "Chest"
		Enums.EquipSlot.WEAPON: return "Weapon"
		Enums.EquipSlot.ACCESSORY: return "Accessory"
	return "?"

func _count_upgradeable(run: RunState) -> int:
	var count = 0
	for cid in run.deck:
		var cd = GameManager.get_card_data(cid)
		if cd and cd.upgrade_id != "":
			count += 1
	return count
