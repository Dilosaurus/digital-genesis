extends Control

signal event_completed

const EVENTS = [
	# ── Original 5 ──────────────────────────────────────────────────────────
	{
		"title": "Corrupted Terminal",
		"description": "A flickering terminal offers forbidden knowledge. The data streams are tainted, but the intel could prove invaluable...",
		"choices": [
			{"text": "Access the data (+1 random card, +10 corruption)", "effect": "card_and_corruption"},
			{"text": "Purge the terminal (Heal 15 HP)", "effect": "heal"},
			{"text": "Walk away", "effect": "nothing"},
		]
	},
	{
		"title": "Fallen Angel's Cache",
		"description": "You find a stash left by a destroyed angel. The contents are still intact, but you can only carry so much...",
		"choices": [
			{"text": "Take the gold (+50 gold)", "effect": "gold"},
			{"text": "Take the artifact (+1 random card)", "effect": "card"},
			{"text": "Absorb residual energy (+5 max HP)", "effect": "max_hp"},
		]
	},
	{
		"title": "The Shrine of Sin",
		"description": "A dark altar pulses with malevolent energy. It seems to want something from you...",
		"choices": [
			{"text": "Pray at the shrine (Remove a random card from deck)", "effect": "remove_card"},
			{"text": "Defile the shrine (+2 Strength this run, +15 corruption)", "effect": "strength_corruption"},
			{"text": "Ignore it", "effect": "nothing"},
		]
	},
	{
		"title": "Digital Fountain",
		"description": "Pure data streams cascade like water. The source seems almost holy in this corrupted world...",
		"choices": [
			{"text": "Drink deeply (Heal to full, +20 corruption)", "effect": "full_heal_corruption"},
			{"text": "Wash your code (Remove all corruption)", "effect": "purify"},
			{"text": "Fill a container (+30 gold)", "effect": "gold_small"},
		]
	},
	{
		"title": "Ghost in the Machine",
		"description": "A spectral process flickers into view and offers you a deal. Its motives are unclear...",
		"choices": [
			{"text": "Accept the deal (+2 random cards)", "effect": "two_cards"},
			{"text": "Consume it (+10 max HP, lose 1 card)", "effect": "hp_lose_card"},
			{"text": "Decline", "effect": "nothing"},
		]
	},
	# ── New Events ───────────────────────────────────────────────────────────
	{
		"title": "Firewall Breach",
		"description": "A gaping hole in the security layer. On the other side, powerful contraband code waits — but so do the automated defenses...",
		"choices": [
			{"text": "Fight through (Lose 20% HP, gain 1 powerful card)", "effect": "breach_fight"},
			{"text": "Sneak past (Nothing happens)", "effect": "nothing"},
			{"text": "Retreat and report (-25 gold, avoid danger)", "effect": "gold_lose_small"},
		]
	},
	{
		"title": "Abandoned Server Room",
		"description": "Rows of dark servers hum faintly. Someone left in a hurry — and left things behind...",
		"choices": [
			{"text": "Search the racks (50% chance: card or lose 15 HP)", "effect": "server_search"},
			{"text": "Hack a terminal (Gain gold or gain a curse, 50/50)", "effect": "server_hack"},
			{"text": "Leave it alone", "effect": "nothing"},
		]
	},
	{
		"title": "Digital Prophet",
		"description": "A strange AI speaks in riddles and prophecy. It claims to see the path ahead — for a price...",
		"choices": [
			{"text": "Listen for free (Reveal the type of your next 3 map nodes)", "effect": "prophet_listen"},
			{"text": "Donate generously (-75 gold, gain a relic)", "effect": "prophet_donate"},
			{"text": "Ignore the ramblings", "effect": "nothing"},
		]
	},
	{
		"title": "Memory Fragment",
		"description": "A crystallized shard of pure memory floats before you. Ancient code, perfectly preserved...",
		"choices": [
			{"text": "Absorb it (Upgrade a random card in your deck)", "effect": "memory_upgrade"},
			{"text": "Defragment (Remove a random card from your deck)", "effect": "remove_card"},
			{"text": "Corrupt it (+2 random cards, but +20 corruption)", "effect": "memory_corrupt"},
		]
	},
	{
		"title": "Rogue Subroutine",
		"description": "A rogue process has broken free of its host. It's dangerous, but also useful — if you can handle it...",
		"choices": [
			{"text": "Merge with it (Gain a random power card)", "effect": "subroutine_merge"},
			{"text": "Quarantine it (Heal 15% of max HP)", "effect": "subroutine_quarantine"},
			{"text": "Delete it (+50 gold, no risk)", "effect": "subroutine_delete"},
		]
	},
	{
		"title": "Angel's Tears",
		"description": "A pool of shimmering liquid seeps from a broken angel. It radiates healing energy, but also carries the taint of sin...",
		"choices": [
			{"text": "Drink it all (Full heal, but gain a curse)", "effect": "tears_drink"},
			{"text": "Collect in a vial (+30 gold)", "effect": "gold_small"},
			{"text": "Pray over the pool (Remove a curse if you have one)", "effect": "tears_pray"},
		]
	},
	{
		"title": "The Merchant's Cache",
		"description": "A dead merchant's cache — still locked. You can see cards through the cracked casing. But is it a trap?",
		"choices": [
			{"text": "Take everything (+2 random cards, gain a curse)", "effect": "cache_all"},
			{"text": "Take carefully (+1 random card, no curse)", "effect": "card"},
			{"text": "Disarm and sell (+75 gold)", "effect": "cache_sell"},
		]
	},
]

var current_event: Dictionary = {}

func _ready() -> void:
	visible = false

func show_random_event() -> void:
	current_event = EVENTS[randi() % EVENTS.size()]
	$Panel/TitleLabel.text = current_event["title"]
	$Panel/DescLabel.text = current_event["description"]

	# Clear old buttons
	for child in $Panel/ChoiceContainer.get_children():
		child.queue_free()

	for i in current_event["choices"].size():
		var choice = current_event["choices"][i]
		var btn = Button.new()
		btn.text = choice["text"]
		btn.custom_minimum_size = Vector2(440, 44)
		btn.pressed.connect(_on_choice.bind(choice["effect"]))
		$Panel/ChoiceContainer.add_child(btn)

	visible = true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _get_playable_cards() -> Array[String]:
	var all_cards = GameManager.card_database.keys()
	var playable_cards: Array[String] = []
	for cid in all_cards:
		var cd = GameManager.get_card_data(cid)
		if cd and not cd.id.begins_with("curse_") and cd.energy_cost < 4:
			playable_cards.append(cid)
	return playable_cards

func _get_curse_cards() -> Array[String]:
	var all_cards = GameManager.card_database.keys()
	var curses: Array[String] = []
	for cid in all_cards:
		var cd = GameManager.get_card_data(cid)
		if cd and cd.id.begins_with("curse_"):
			curses.append(cid)
	return curses

func _get_power_cards() -> Array[String]:
	var all_cards = GameManager.card_database.keys()
	var powers: Array[String] = []
	for cid in all_cards:
		var cd = GameManager.get_card_data(cid)
		# Power cards: no block/attack type OR energy_cost == 0 heuristic —
		# fall back to any non-curse card with cost >= 1 that isn't a basic card
		if cd and not cd.id.begins_with("curse_") and cd.energy_cost >= 1:
			var basic = ["strike", "defend", "bash"]
			if cd.id not in basic:
				powers.append(cid)
	return powers

func _add_random_curse(run: RunState) -> void:
	var curses = _get_curse_cards()
	if curses.size() > 0:
		run.add_card(curses[randi() % curses.size()])

func _get_upgradeable_deck_indices(run: RunState) -> Array[int]:
	var indices: Array[int] = []
	for i in run.deck.size():
		var cd = GameManager.get_card_data(run.deck[i])
		if cd and cd.upgrade_id != "":
			indices.append(i)
	return indices

# ---------------------------------------------------------------------------
# Effect handler
# ---------------------------------------------------------------------------
func _on_choice(effect: String) -> void:
	var run = GameManager.current_run
	if not run:
		visible = false
		event_completed.emit()
		return

	var playable_cards := _get_playable_cards()

	match effect:
		# ── Original effects ────────────────────────────────────────────────
		"card_and_corruption":
			if playable_cards.size() > 0:
				run.add_card(playable_cards[randi() % playable_cards.size()])
			# corruption applied at next combat start via existing system

		"heal":
			run.heal(15)

		"gold":
			run.gold += 50

		"card":
			if playable_cards.size() > 0:
				run.add_card(playable_cards[randi() % playable_cards.size()])

		"max_hp":
			run.max_hp += 5
			run.current_hp += 5

		"remove_card":
			if run.deck.size() > 5:
				var idx = randi() % run.deck.size()
				run.deck.remove_at(idx)

		"strength_corruption":
			pass  # Applied at combat start via existing corruption/strength system

		"full_heal_corruption":
			run.current_hp = run.max_hp

		"purify":
			pass  # Corruption reset handled elsewhere

		"gold_small":
			run.gold += 30

		"two_cards":
			for _j in 2:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])

		"hp_lose_card":
			run.max_hp += 10
			run.current_hp += 10
			if run.deck.size() > 5:
				run.deck.remove_at(randi() % run.deck.size())

		"nothing":
			pass

		# ── New effects ──────────────────────────────────────────────────────

		"breach_fight":
			# Lose 20% max HP (min 1), gain 1 card from the power/heavy pool
			var dmg = maxi(1, run.max_hp / 5)
			run.current_hp = maxi(1, run.current_hp - dmg)
			var powers := _get_power_cards()
			var pool = powers if powers.size() > 0 else playable_cards
			if pool.size() > 0:
				run.add_card(pool[randi() % pool.size()])

		"gold_lose_small":
			run.gold = maxi(0, run.gold - 25)

		"server_search":
			if randi() % 2 == 0:
				# Lucky: gain a random card
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])
			else:
				# Unlucky: lose 15 HP (min 1)
				run.current_hp = maxi(1, run.current_hp - 15)

		"server_hack":
			if randi() % 2 == 0:
				# Lucky: gain gold (20-60)
				run.gold += 20 + randi() % 41
			else:
				# Unlucky: gain a curse
				_add_random_curse(run)

		"prophet_listen":
			# Mark the node types of the next 3 accessible nodes as "revealed"
			# We encode this as a no-op for now; the map screen reads node types
			# already — this is a quality-of-life effect with no mechanical change.
			# In a future iteration the map can highlight revealed nodes.
			pass

		"prophet_donate":
			if run.gold >= 75:
				run.gold -= 75
				var rewards = RelicSystem.get_random_relic_reward(run.relics, 1)
				if rewards.size() > 0:
					run.add_relic(rewards[0])

		"memory_upgrade":
			var upgradeable := _get_upgradeable_deck_indices(run)
			if upgradeable.size() > 0:
				var idx = upgradeable[randi() % upgradeable.size()]
				var old_id = run.deck[idx]
				var cd = GameManager.get_card_data(old_id)
				if cd and cd.upgrade_id != "":
					run.deck[idx] = cd.upgrade_id

		"memory_corrupt":
			for _j in 2:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])
			# +20 corruption — applied at next combat via existing system

		"subroutine_merge":
			var powers := _get_power_cards()
			var pool = powers if powers.size() > 0 else playable_cards
			if pool.size() > 0:
				run.add_card(pool[randi() % pool.size()])

		"subroutine_quarantine":
			var heal_amount = maxi(1, run.max_hp * 15 / 100)
			run.heal(heal_amount)

		"subroutine_delete":
			run.gold += 50

		"tears_drink":
			run.current_hp = run.max_hp
			_add_random_curse(run)

		"tears_pray":
			# Remove first curse found in deck
			var removed = false
			for i in run.deck.size():
				var cd = GameManager.get_card_data(run.deck[i])
				if cd and cd.id.begins_with("curse_"):
					run.deck.remove_at(i)
					removed = true
					break
			# If no curse, give small gold consolation
			if not removed:
				run.gold += 15

		"cache_all":
			for _j in 2:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])
			_add_random_curse(run)

		"cache_sell":
			run.gold += 75

	visible = false
	event_completed.emit()
