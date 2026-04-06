extends Control

signal event_completed

const FONT_MEDIEVAL = preload("res://assets/fonts/MedievalSharp.ttf")
const FONT_MONO = preload("res://assets/fonts/ShareTechMono-Regular.ttf")
const FONT_LATO = preload("res://assets/fonts/Lato-Regular.ttf")

const EVENTS = [
	# ── Original 5 — available in all acts ───────────────────────────────
	{
		"title": "Corrupted Terminal",
		"acts": [1, 2, 3],
		"description": "A flickering terminal offers forbidden knowledge. The data streams are tainted, but the intel could prove invaluable...",
		"choices": [
			{"text": "Access the data (+1 random card, +10 corruption)", "effect": "card_and_corruption"},
			{"text": "Purge the terminal (Heal 15 HP)", "effect": "heal"},
			{"text": "Walk away", "effect": "nothing"},
		]
	},
	{
		"title": "Fallen Angel's Cache",
		"acts": [1, 2, 3],
		"description": "You find a stash left by a destroyed angel. The contents are still intact, but you can only carry so much...",
		"choices": [
			{"text": "Take the gold (+50 gold)", "effect": "gold"},
			{"text": "Take the artifact (+1 random card)", "effect": "card"},
			{"text": "Absorb residual energy (+5 max HP)", "effect": "max_hp"},
		]
	},
	{
		"title": "The Shrine of Sin",
		"acts": [1, 2, 3],
		"description": "A dark altar pulses with malevolent energy. It seems to want something from you...",
		"choices": [
			{"text": "Pray at the shrine (Remove a random card from deck)", "effect": "remove_card"},
			{"text": "Defile the shrine (+2 Strength this run, +15 corruption)", "effect": "strength_corruption"},
			{"text": "Ignore it", "effect": "nothing"},
		]
	},
	{
		"title": "Digital Fountain",
		"acts": [1, 2],
		"description": "Pure data streams cascade like water. The source seems almost holy in this corrupted world...",
		"choices": [
			{"text": "Drink deeply (Heal to full, +20 corruption)", "effect": "full_heal_corruption"},
			{"text": "Wash your code (Remove all corruption)", "effect": "purify"},
			{"text": "Fill a container (+30 gold)", "effect": "gold_small"},
		]
	},
	{
		"title": "Ghost in the Machine",
		"acts": [1, 2],
		"description": "A spectral process flickers into view and offers you a deal. Its motives are unclear...",
		"choices": [
			{"text": "Accept the deal (+2 random cards)", "effect": "two_cards"},
			{"text": "Consume it (+10 max HP, lose 1 card)", "effect": "hp_lose_card"},
			{"text": "Decline", "effect": "nothing"},
		]
	},
	# ── Act 1 events ─────────────────────────────────────────────────────
	{
		"title": "Firewall Breach",
		"acts": [1],
		"description": "A gaping hole in the security layer. On the other side, powerful contraband code waits — but so do the automated defenses...",
		"choices": [
			{"text": "Fight through (Lose 20% HP, gain 1 powerful card)", "effect": "breach_fight"},
			{"text": "Sneak past (Nothing happens)", "effect": "nothing"},
			{"text": "Retreat and report (-25 gold, avoid danger)", "effect": "gold_lose_small"},
		]
	},
	{
		"title": "Abandoned Server Room",
		"acts": [1],
		"description": "Rows of dark servers hum faintly. Someone left in a hurry — and left things behind...",
		"choices": [
			{"text": "Search the racks (50% chance: card or lose 15 HP)", "effect": "server_search"},
			{"text": "Hack a terminal (Gain gold or gain a curse, 50/50)", "effect": "server_hack"},
			{"text": "Leave it alone", "effect": "nothing"},
		]
	},
	{
		"title": "Digital Prophet",
		"acts": [1, 2],
		"description": "A strange AI speaks in riddles and prophecy. It claims to see the path ahead — for a price...",
		"choices": [
			{"text": "Listen for free (Reveal the type of your next 3 map nodes)", "effect": "prophet_listen"},
			{"text": "Donate generously (-75 gold, gain a relic)", "effect": "prophet_donate"},
			{"text": "Ignore the ramblings", "effect": "nothing"},
		]
	},
	{
		"title": "Memory Fragment",
		"acts": [1, 2],
		"description": "A crystallized shard of pure memory floats before you. Ancient code, perfectly preserved...",
		"choices": [
			{"text": "Absorb it (Upgrade a random card in your deck)", "effect": "memory_upgrade"},
			{"text": "Defragment (Remove a random card from your deck)", "effect": "remove_card"},
			{"text": "Corrupt it (+2 random cards, but +20 corruption)", "effect": "memory_corrupt"},
		]
	},
	{
		"title": "Rogue Subroutine",
		"acts": [1, 2, 3],
		"description": "A rogue process has broken free of its host. It's dangerous, but also useful — if you can handle it...",
		"choices": [
			{"text": "Merge with it (Gain a random power card)", "effect": "subroutine_merge"},
			{"text": "Quarantine it (Heal 15% of max HP)", "effect": "subroutine_quarantine"},
			{"text": "Delete it (+50 gold, no risk)", "effect": "subroutine_delete"},
		]
	},
	{
		"title": "Angel's Tears",
		"acts": [1, 2, 3],
		"description": "A pool of shimmering liquid seeps from a broken angel. It radiates healing energy, but also carries the taint of sin...",
		"choices": [
			{"text": "Drink it all (Full heal, but gain a curse)", "effect": "tears_drink"},
			{"text": "Collect in a vial (+30 gold)", "effect": "gold_small"},
			{"text": "Pray over the pool (Remove a curse if you have one)", "effect": "tears_pray"},
		]
	},
	{
		"title": "The Merchant's Cache",
		"acts": [1, 2],
		"description": "A dead merchant's cache — still locked. You can see cards through the cracked casing. But is it a trap?",
		"choices": [
			{"text": "Take everything (+2 random cards, gain a curse)", "effect": "cache_all"},
			{"text": "Take carefully (+1 random card, no curse)", "effect": "card"},
			{"text": "Disarm and sell (+75 gold)", "effect": "cache_sell"},
		]
	},
	# ── Act 2: Rift-themed events ────────────────────────────────────────
	{
		"title": "Rift Anomaly",
		"acts": [2],
		"description": "A tear in the data fabric pulses with unstable energy. Reality warps around it — you can feel your own code destabilizing...",
		"choices": [
			{"text": "Step through (Gain 2 random cards, +15 corruption)", "effect": "rift_step"},
			{"text": "Absorb the energy (+10 Max HP, +10 corruption)", "effect": "rift_absorb"},
			{"text": "Stabilize the tear (Heal 20 HP, no risk)", "effect": "rift_stabilize"},
		]
	},
	{
		"title": "Data Smuggler",
		"acts": [2],
		"description": "A shady process approaches you in the Rift. It deals in black-market code — powerful but unreliable...",
		"choices": [
			{"text": "Buy premium code (-60 gold, gain 1 powerful card)", "effect": "smuggler_buy"},
			{"text": "Trade a card (Remove 1 card, gain 1 random card + 30 gold)", "effect": "smuggler_trade"},
			{"text": "Report the smuggler (+25 gold bounty)", "effect": "smuggler_report"},
		]
	},
	{
		"title": "Corrupted Mirror",
		"acts": [2],
		"description": "A reflective data surface shows a twisted version of yourself. Your mirror image offers a dark bargain...",
		"choices": [
			{"text": "Embrace your shadow (Upgrade 2 random cards, +25 corruption)", "effect": "mirror_embrace"},
			{"text": "Shatter the mirror (+3 random cards, but 1 is a curse)", "effect": "mirror_shatter"},
			{"text": "Turn away (Nothing happens)", "effect": "nothing"},
		]
	},
	{
		"title": "The Breach Echo",
		"acts": [2],
		"description": "An echo of the original Breach ripples through the Rift. For a moment, the walls between worlds thin...",
		"choices": [
			{"text": "Listen to the echo (Remove all corruption, lose 15% max HP)", "effect": "echo_listen"},
			{"text": "Channel the Breach (+75 gold, +20 corruption)", "effect": "echo_channel"},
			{"text": "Shield yourself (Gain 15 Block next combat)", "effect": "echo_shield"},
		]
	},
	# ── Act 3: Core-themed events ────────────────────────────────────────
	{
		"title": "Angel's Last Offer",
		"acts": [3],
		"description": "A dying angel process materializes before you. It offers its remaining power in exchange for mercy...",
		"choices": [
			{"text": "Accept its power (Upgrade 3 random cards, +30 corruption)", "effect": "angel_accept"},
			{"text": "Grant mercy (Full heal, remove 1 curse if present)", "effect": "angel_mercy"},
			{"text": "Destroy it (+100 gold)", "effect": "angel_destroy"},
		]
	},
	{
		"title": "The Core Fragment",
		"acts": [3],
		"description": "A shard of the Nexus Core itself floats before you, pulsing with immense computational power...",
		"choices": [
			{"text": "Integrate it (+15 Max HP, +1 Energy next combat)", "effect": "core_integrate"},
			{"text": "Decode it (Upgrade all cards of one type, +15 corruption)", "effect": "core_decode"},
			{"text": "Weaponize it (+1 powerful card, lose 20% current HP)", "effect": "core_weaponize"},
		]
	},
	{
		"title": "Fallen Comrade",
		"acts": [3],
		"description": "You find the remnants of a GENESIS operative who didn't make it this far. Their equipment is damaged but salvageable...",
		"choices": [
			{"text": "Take their deck data (+3 random cards)", "effect": "comrade_deck"},
			{"text": "Salvage equipment (+80 gold, +5 Max HP)", "effect": "comrade_salvage"},
			{"text": "Honor their memory (Full heal)", "effect": "comrade_honor"},
		]
	},
	{
		"title": "The Final Terminal",
		"acts": [3],
		"description": "The last terminal before the Core's inner sanctum. Its screen displays a single prompt: PURGE OR CORRUPT?",
		"choices": [
			{"text": "PURGE (Remove all corruption, lose 2 random cards)", "effect": "terminal_purge"},
			{"text": "CORRUPT (Remove 3 cards of choice, +40 corruption)", "effect": "terminal_corrupt"},
			{"text": "REBOOT (+20 Max HP, shuffle entire deck)", "effect": "terminal_reboot"},
		]
	},
	# ── Phase 5 Stream C: New currency & risk/reward events ──────────────────

	# ── Act 1: Corrupted Server Farm ─────────────────────────────────────────
	{
		"title": "Data Leak",
		"acts": [1],
		"description": "A corrupted database is hemorrhaging data into the network. Streams of raw information cascade down the walls — valuable, but tainted with malicious code...",
		"choices": [
			{"text": "Download the data (+2 random cards, +10 corruption)", "effect": "data_leak_download"},
			{"text": "Patch the leak (Heal 20 HP, +25 gold)", "effect": "data_leak_patch"},
			{"text": "Sell access (+75 gold)", "effect": "data_leak_sell"},
		]
	},
	{
		"title": "Abandoned Server Rack",
		"acts": [1],
		"description": "A functioning server cluster hums quietly in the darkness. Its processing power is immense — someone left it running when the world fell apart...",
		"choices": [
			{"text": "Overclock it (+5 Max HP, +5 corruption)", "effect": "server_rack_overclock"},
			{"text": "Salvage parts (+1 Crystal, +30 gold)", "effect": "server_rack_salvage"},
			{"text": "Leave it running (+50 gold)", "effect": "server_rack_leave"},
		]
	},
	{
		"title": "Corrupted AI Fragment",
		"acts": [1],
		"description": "A piece of corrupted AI flickers in and out of existence before you. It speaks in fractured syllables, offering to merge its processing power with yours...",
		"choices": [
			{"text": "Accept the merge (+2 random cards, +15 corruption, +1 Soul)", "effect": "ai_fragment_merge"},
			{"text": "Destroy it (Remove 10 corruption)", "effect": "ai_fragment_destroy"},
			{"text": "Contain it (+2 Crystals)", "effect": "ai_fragment_contain"},
		]
	},
	# ── Act 2: Neural Cathedral ──────────────────────────────────────────────
	{
		"title": "Digital Confession Booth",
		"acts": [2],
		"description": "A holographic priest materializes within an ornate data structure. Its voice echoes with static as it intones: 'Confess, child of the machine...'",
		"choices": [
			{"text": "Confess your sins (Reset all sin counters)", "effect": "confession_confess"},
			{"text": "Demand absolution (Heal to full, +25 corruption)", "effect": "confession_absolve"},
			{"text": "Rob the collection plate (+80 gold, +2 Wrath sin)", "effect": "confession_rob"},
		]
	},
	{
		"title": "Angelic Armory",
		"acts": [2],
		"description": "Behind a cracked divine seal lies a cache of celestial weapons. They pulse with holy energy — powerful but volatile in mortal hands...",
		"choices": [
			{"text": "Take a weapon (+1 random equipment)", "effect": "armory_weapon"},
			{"text": "Take the blueprints (+1 Crystal, +1 Soul)", "effect": "armory_blueprints"},
			{"text": "Smash everything (+10 Max HP, +1 Crystal)", "effect": "armory_smash"},
		]
	},
	{
		"title": "Memory Pool",
		"acts": [2],
		"description": "A shimmering pool of liquid data ripples gently before you. Ancient memories swirl beneath its surface — lives lived, code written, worlds compiled...",
		"choices": [
			{"text": "Dive in (Remove a random card, +10 Max HP)", "effect": "pool_dive"},
			{"text": "Drink (Heal to full)", "effect": "pool_drink"},
			{"text": "Fill a vial (+2 Souls, +5 corruption)", "effect": "pool_vial"},
		]
	},
	{
		"title": "The Firewall Oracle",
		"acts": [2],
		"description": "A prophetic subroutine speaks in riddles from behind a wall of cascading firewall code. It offers knowledge — but every answer carries a price...",
		"choices": [
			{"text": "Ask about power (+10 Max HP, +20 corruption)", "effect": "oracle_power"},
			{"text": "Ask about survival (+15 Max HP, remove 2 random cards)", "effect": "oracle_survival"},
			{"text": "Ask about wealth (+100 gold, +3 Crystals)", "effect": "oracle_wealth"},
			{"text": "Silence the oracle (+2 Souls, +10 corruption)", "effect": "oracle_silence"},
		]
	},
	# ── Act 3: The Void Core ─────────────────────────────────────────────────
	{
		"title": "Void Rift",
		"acts": [3],
		"description": "A tear in reality leaks raw computational power. The fabric of the digital world frays at its edges, and you can feel your own code destabilizing near it...",
		"choices": [
			{"text": "Absorb the energy (+15 Max HP, +30 corruption, -10 max HP after)", "effect": "void_absorb"},
			{"text": "Seal the rift (Remove 25 corruption, +1 Soul)", "effect": "void_seal"},
			{"text": "Study it (+3 Crystals, +2 Souls)", "effect": "void_study"},
		]
	},
	{
		"title": "Fallen Seraph",
		"acts": [3],
		"description": "A destroyed angel's core still pulses with fading light. Its divine energy is immense — enough to reshape your entire being, if you dare absorb it...",
		"choices": [
			{"text": "Harvest the core (+3 Souls, +20 corruption, +3 random cards)", "effect": "seraph_harvest"},
			{"text": "Purify it (Heal to full, remove all corruption)", "effect": "seraph_purify"},
			{"text": "Sell the remains (+150 gold, +2 Crystals)", "effect": "seraph_sell"},
		]
	},
	{
		"title": "The Merchant of Souls",
		"acts": [3],
		"description": "A mysterious figure cloaked in shifting data patterns sits behind a counter of pure void. 'I deal in the only currency that matters,' it whispers...",
		"choices": [
			{"text": "Buy power (Spend 2 Souls: +10 Max HP, +2 random cards)", "effect": "soul_merchant_power"},
			{"text": "Buy health (Spend 1 Soul: +20 Max HP, heal to full)", "effect": "soul_merchant_health"},
			{"text": "Buy knowledge (Spend 3 Souls: +3 random cards, remove 2 random cards)", "effect": "soul_merchant_knowledge"},
			{"text": "Rob the merchant (+3 Souls, +25 corruption, lose 30% HP)", "effect": "soul_merchant_rob"},
		]
	},
	# ── Universal: all acts ──────────────────────────────────────────────────
	{
		"title": "Glitch in the Matrix",
		"acts": [1, 2, 3],
		"description": "Reality stutters for a moment. The world around you freezes, skips, then resumes — but something has changed. A seam in the code is exposed...",
		"choices": [
			{"text": "Exploit the glitch (+2 random cards, +10 corruption)", "effect": "glitch_exploit"},
			{"text": "Stabilize (Heal 15 HP, +1 Crystal)", "effect": "glitch_stabilize"},
			{"text": "Ignore it (Nothing happens)", "effect": "nothing"},
		]
	},
	{
		"title": "Rogue Process",
		"acts": [1, 2, 3],
		"description": "A wild AI process flickers into existence, its code writhing with chaotic energy. It speaks in rapid bursts: 'Trade? Trade! I want what you have...'",
		"choices": [
			{"text": "Trade HP for power (-15 HP, +5 Max HP, +1 Soul)", "effect": "rogue_trade_hp"},
			{"text": "Trade cards for gold (Remove 2 random cards, +100 gold)", "effect": "rogue_trade_cards"},
			{"text": "Trade corruption for souls (+20 corruption, +2 Souls)", "effect": "rogue_trade_corruption"},
		]
	},
	{
		"title": "The Architect's Blueprint",
		"acts": [1, 2, 3],
		"description": "Ancient system schematics hover in the air, projected by a long-dead terminal. The plans describe structures of immense complexity and power...",
		"choices": [
			{"text": "Study the schematics (+5 Max HP, +1 Skill Point)", "effect": "blueprint_study"},
			{"text": "Sell the blueprints (+120 gold)", "effect": "blueprint_sell"},
			{"text": "Destroy them (Heal 20 HP, remove 15 corruption)", "effect": "blueprint_destroy"},
		]
	},
	{
		"title": "Quantum Entanglement",
		"acts": [2, 3],
		"description": "Two realities momentarily overlap. You see yourself in another timeline — stronger in some ways, weaker in others. The convergence won't last long...",
		"choices": [
			{"text": "Choose this reality (Remove 2 random cards, +2 Crystals)", "effect": "quantum_this"},
			{"text": "Choose the other (+3 random cards, +15 corruption)", "effect": "quantum_other"},
			{"text": "Exist in both (+5 Max HP, +5 corruption, +1 Crystal)", "effect": "quantum_both"},
		]
	},
	{
		"title": "The Corrupted Merchant",
		"acts": [1, 2, 3],
		"description": "A vendor materializes from corrupted code, its wares flickering between valuable and worthless. 'Everything must go,' it hisses, 'one way or another...'",
		"choices": [
			{"text": "Buy cheap (+2 random cards, +10 corruption)", "effect": "corrupt_merchant_cheap"},
			{"text": "Buy premium (-75 gold, +1 random equipment)", "effect": "corrupt_merchant_premium"},
			{"text": "Pickpocket (+50 gold, 50% chance +20 corruption)", "effect": "corrupt_merchant_pickpocket"},
		]
	},
]

var current_event: Dictionary = {}

func _ready() -> void:
	visible = false

func show_random_event() -> void:
	# Filter events by current act
	var act: int = 1
	if GameManager.is_run_active():
		act = GameManager.current_run.act

	var eligible: Array = []
	for event in EVENTS:
		var acts: Array = event.get("acts", [1, 2, 3])
		if act in acts:
			eligible.append(event)

	# Fallback: if no eligible events, use all
	if eligible.is_empty():
		eligible = EVENTS.duplicate()

	current_event = eligible[randi() % eligible.size()]
	$Panel/TitleLabel.text = current_event["title"]
	$Panel/TitleLabel.add_theme_font_override("font", FONT_MEDIEVAL)
	$Panel/TitleLabel.add_theme_font_size_override("font_size", 28)
	$Panel/TitleLabel.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

	$Panel/DescPanel/DescLabel.text = current_event["description"]
	$Panel/DescPanel/DescLabel.add_theme_font_override("font", FONT_LATO)
	$Panel/DescPanel/DescLabel.add_theme_font_size_override("font_size", 15)
	$Panel/DescPanel/DescLabel.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95))

	# Clear old buttons
	for child in $Panel/ChoiceContainer.get_children():
		child.queue_free()

	for i in current_event["choices"].size():
		var choice = current_event["choices"][i]
		var btn = Button.new()
		btn.text = choice["text"]
		btn.custom_minimum_size = Vector2(552, 48)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = false
		btn.autowrap_mode = TextServer.AUTOWRAP_OFF
		# Apply custom choice styling
		btn.add_theme_stylebox_override("normal", _choice_style_normal())
		btn.add_theme_stylebox_override("hover", _choice_style_hover())
		btn.add_theme_stylebox_override("pressed", _choice_style_pressed())
		btn.add_theme_font_override("font", FONT_LATO)
		btn.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95))
		btn.add_theme_color_override("font_hover_color", Color(1.00, 1.00, 1.00, 1.00))
		btn.add_theme_font_size_override("font_size", 14)
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

		# ── Act 1 effects ────────────────────────────────────────────────────

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

		# ── Act 2: Rift effects ──────────────────────────────────────────────

		"rift_step":
			for _j in 2:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])
			run.run_corruption = mini(run.run_corruption + 15, run.max_corruption)

		"rift_absorb":
			run.max_hp += 10
			run.current_hp += 10
			run.run_corruption = mini(run.run_corruption + 10, run.max_corruption)

		"rift_stabilize":
			run.heal(20)

		"smuggler_buy":
			if run.gold >= 60:
				run.gold -= 60
				var powers := _get_power_cards()
				var pool = powers if powers.size() > 0 else playable_cards
				if pool.size() > 0:
					run.add_card(pool[randi() % pool.size()])

		"smuggler_trade":
			if run.deck.size() > 5:
				run.deck.remove_at(randi() % run.deck.size())
			if playable_cards.size() > 0:
				run.add_card(playable_cards[randi() % playable_cards.size()])
			run.gold += 30

		"smuggler_report":
			run.gold += 25

		"mirror_embrace":
			var upgradeable := _get_upgradeable_deck_indices(run)
			# Upgrade up to 2 random cards
			for _j in mini(2, upgradeable.size()):
				if upgradeable.size() > 0:
					var pick = randi() % upgradeable.size()
					var idx = upgradeable[pick]
					var cd = GameManager.get_card_data(run.deck[idx])
					if cd and cd.upgrade_id != "":
						run.deck[idx] = cd.upgrade_id
					upgradeable.remove_at(pick)
			run.run_corruption = mini(run.run_corruption + 25, run.max_corruption)

		"mirror_shatter":
			for _j in 3:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])
			_add_random_curse(run)

		"echo_listen":
			run.run_corruption = 0
			var hp_loss = maxi(1, run.max_hp * 15 / 100)
			run.max_hp = maxi(1, run.max_hp - hp_loss)
			run.current_hp = mini(run.current_hp, run.max_hp)

		"echo_channel":
			run.gold += 75
			run.run_corruption = mini(run.run_corruption + 20, run.max_corruption)

		"echo_shield":
			# Small heal as stand-in for "block next combat" (no persistent block system)
			run.heal(10)

		# ── Act 3: Core effects ──────────────────────────────────────────────

		"angel_accept":
			var upgradeable := _get_upgradeable_deck_indices(run)
			for _j in mini(3, upgradeable.size()):
				if upgradeable.size() > 0:
					var pick = randi() % upgradeable.size()
					var idx = upgradeable[pick]
					var cd = GameManager.get_card_data(run.deck[idx])
					if cd and cd.upgrade_id != "":
						run.deck[idx] = cd.upgrade_id
					upgradeable.remove_at(pick)
			run.run_corruption = mini(run.run_corruption + 30, run.max_corruption)

		"angel_mercy":
			run.current_hp = run.max_hp
			# Remove first curse
			for i in run.deck.size():
				var cd = GameManager.get_card_data(run.deck[i])
				if cd and cd.id.begins_with("curse_"):
					run.deck.remove_at(i)
					break

		"angel_destroy":
			run.gold += 100

		"core_integrate":
			run.max_hp += 15
			run.current_hp += 15

		"core_decode":
			# Upgrade all cards of one random type
			var upgradeable := _get_upgradeable_deck_indices(run)
			if upgradeable.size() > 0:
				# Pick a card type from the first upgradeable card
				var ref_idx = upgradeable[randi() % upgradeable.size()]
				var ref_cd = GameManager.get_card_data(run.deck[ref_idx])
				if ref_cd:
					var target_type = ref_cd.card_type
					for idx in upgradeable:
						var cd = GameManager.get_card_data(run.deck[idx])
						if cd and cd.card_type == target_type and cd.upgrade_id != "":
							run.deck[idx] = cd.upgrade_id
			run.run_corruption = mini(run.run_corruption + 15, run.max_corruption)

		"core_weaponize":
			var powers := _get_power_cards()
			var pool = powers if powers.size() > 0 else playable_cards
			if pool.size() > 0:
				run.add_card(pool[randi() % pool.size()])
			var dmg = maxi(1, run.current_hp / 5)
			run.current_hp = maxi(1, run.current_hp - dmg)

		"comrade_deck":
			for _j in 3:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])

		"comrade_salvage":
			run.gold += 80
			run.max_hp += 5
			run.current_hp += 5

		"comrade_honor":
			run.current_hp = run.max_hp

		"terminal_purge":
			run.run_corruption = 0
			# Remove 2 random cards
			for _j in 2:
				if run.deck.size() > 5:
					run.deck.remove_at(randi() % run.deck.size())

		"terminal_corrupt":
			# Remove 3 random cards (simplified from "of choice")
			for _j in 3:
				if run.deck.size() > 5:
					run.deck.remove_at(randi() % run.deck.size())
			run.run_corruption = mini(run.run_corruption + 40, run.max_corruption)

		"terminal_reboot":
			run.max_hp += 20
			run.current_hp += 20

		# ── Phase 5 Stream C: New event effects ─────────────────────────────

		# -- Act 1: Corrupted Server Farm --

		"data_leak_download":
			for _j in 2:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])
			run.run_corruption = mini(run.run_corruption + 10, run.max_corruption)

		"data_leak_patch":
			run.heal(20)
			run.gold += 25

		"data_leak_sell":
			run.gold += 75

		"server_rack_overclock":
			run.max_hp += 5
			run.current_hp += 5
			run.run_corruption = mini(run.run_corruption + 5, run.max_corruption)

		"server_rack_salvage":
			run.crystals += 1
			run.gold += 30

		"server_rack_leave":
			run.gold += 50

		"ai_fragment_merge":
			for _j in 2:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])
			run.run_corruption = mini(run.run_corruption + 15, run.max_corruption)
			run.souls += 1

		"ai_fragment_destroy":
			run.run_corruption = maxi(run.run_corruption - 10, 0)

		"ai_fragment_contain":
			run.crystals += 2

		# -- Act 2: Neural Cathedral --

		"confession_confess":
			# Reset sin counters on the PlayerState (accessed via combat_state or
			# stored between combats). Since we are between combats, we stash a
			# flag on RunState that the combat engine reads at combat start.
			# Simplified: we set corruption_essence as a "purity token" that the
			# sin_system can check. For now, directly zero the persistent sins
			# by accessing the autoload's last known player state.
			# Pragmatic approach: store a flag the combat engine will honour.
			if not run.has_meta("sins_reset"):
				run.set_meta("sins_reset", true)

		"confession_absolve":
			run.current_hp = run.max_hp
			run.run_corruption = mini(run.run_corruption + 25, run.max_corruption)

		"confession_rob":
			run.gold += 80
			# +2 Wrath sin — stored as corruption_essence which feeds sin at combat start
			run.corruption_essence += 2

		# -- Angelic Armory --

		"armory_weapon":
			var equip_rewards = EquipmentSystem.get_random_equipment_reward(run.equipment, 1)
			if equip_rewards.size() > 0:
				EquipmentSystem.equip(run, equip_rewards[0])

		"armory_blueprints":
			run.crystals += 1
			run.souls += 1

		"armory_smash":
			run.max_hp += 10
			run.current_hp += 10
			run.crystals += 1

		# -- Memory Pool --

		"pool_dive":
			if run.deck.size() > 5:
				run.deck.remove_at(randi() % run.deck.size())
			run.max_hp += 10
			run.current_hp += 10

		"pool_drink":
			run.current_hp = run.max_hp

		"pool_vial":
			run.souls += 2
			run.run_corruption = mini(run.run_corruption + 5, run.max_corruption)

		# -- The Firewall Oracle --

		"oracle_power":
			run.max_hp += 10
			run.current_hp += 10
			run.run_corruption = mini(run.run_corruption + 20, run.max_corruption)

		"oracle_survival":
			run.max_hp += 15
			run.current_hp += 15
			for _j in 2:
				if run.deck.size() > 5:
					run.deck.remove_at(randi() % run.deck.size())

		"oracle_wealth":
			run.gold += 100
			run.crystals += 3

		"oracle_silence":
			run.souls += 2
			run.run_corruption = mini(run.run_corruption + 10, run.max_corruption)

		# -- Act 3: The Void Core --

		"void_absorb":
			# Net effect: +5 Max HP (+15 then -10), +30 corruption
			run.max_hp += 15
			run.current_hp += 15
			run.run_corruption = mini(run.run_corruption + 30, run.max_corruption)
			run.max_hp = maxi(run.max_hp - 10, 1)
			run.current_hp = mini(run.current_hp, run.max_hp)

		"void_seal":
			run.run_corruption = maxi(run.run_corruption - 25, 0)
			run.souls += 1

		"void_study":
			run.crystals += 3
			run.souls += 2

		# -- Fallen Seraph --

		"seraph_harvest":
			run.souls += 3
			run.run_corruption = mini(run.run_corruption + 20, run.max_corruption)
			for _j in 3:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])

		"seraph_purify":
			run.current_hp = run.max_hp
			run.run_corruption = 0

		"seraph_sell":
			run.gold += 150
			run.crystals += 2

		# -- The Merchant of Souls --

		"soul_merchant_power":
			if run.souls >= 2:
				run.souls -= 2
				run.max_hp += 10
				run.current_hp += 10
				for _j in 2:
					if playable_cards.size() > 0:
						run.add_card(playable_cards[randi() % playable_cards.size()])
			# If not enough souls, nothing happens (choice is a gamble)

		"soul_merchant_health":
			if run.souls >= 1:
				run.souls -= 1
				run.max_hp += 20
				run.current_hp = run.max_hp

		"soul_merchant_knowledge":
			if run.souls >= 3:
				run.souls -= 3
				for _j in 3:
					if playable_cards.size() > 0:
						run.add_card(playable_cards[randi() % playable_cards.size()])
				for _j in 2:
					if run.deck.size() > 5:
						run.deck.remove_at(randi() % run.deck.size())

		"soul_merchant_rob":
			run.souls += 3
			run.run_corruption = mini(run.run_corruption + 25, run.max_corruption)
			# Lose 30% current HP
			var hp_loss = maxi(1, run.current_hp * 30 / 100)
			run.current_hp = maxi(1, run.current_hp - hp_loss)

		# -- Universal events --

		"glitch_exploit":
			for _j in 2:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])
			run.run_corruption = mini(run.run_corruption + 10, run.max_corruption)

		"glitch_stabilize":
			run.heal(15)
			run.crystals += 1

		"rogue_trade_hp":
			run.current_hp = maxi(1, run.current_hp - 15)
			run.max_hp += 5
			run.current_hp += 5
			run.souls += 1

		"rogue_trade_cards":
			for _j in 2:
				if run.deck.size() > 5:
					run.deck.remove_at(randi() % run.deck.size())
			run.gold += 100

		"rogue_trade_corruption":
			run.run_corruption = mini(run.run_corruption + 20, run.max_corruption)
			run.souls += 2

		"blueprint_study":
			run.max_hp += 5
			run.current_hp += 5
			run.skill_points += 1

		"blueprint_sell":
			run.gold += 120

		"blueprint_destroy":
			run.heal(20)
			run.run_corruption = maxi(run.run_corruption - 15, 0)

		"quantum_this":
			for _j in 2:
				if run.deck.size() > 5:
					run.deck.remove_at(randi() % run.deck.size())
			run.crystals += 2

		"quantum_other":
			for _j in 3:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])
			run.run_corruption = mini(run.run_corruption + 15, run.max_corruption)

		"quantum_both":
			run.max_hp += 5
			run.current_hp += 5
			run.run_corruption = mini(run.run_corruption + 5, run.max_corruption)
			run.crystals += 1

		"corrupt_merchant_cheap":
			for _j in 2:
				if playable_cards.size() > 0:
					run.add_card(playable_cards[randi() % playable_cards.size()])
			run.run_corruption = mini(run.run_corruption + 10, run.max_corruption)

		"corrupt_merchant_premium":
			if run.gold >= 75:
				run.gold -= 75
				var equip_rewards = EquipmentSystem.get_random_equipment_reward(run.equipment, 1)
				if equip_rewards.size() > 0:
					EquipmentSystem.equip(run, equip_rewards[0])

		"corrupt_merchant_pickpocket":
			run.gold += 50
			if randi() % 2 == 0:
				run.run_corruption = mini(run.run_corruption + 20, run.max_corruption)

	visible = false
	event_completed.emit()

# ── Choice button styles ──────────────────────────────────────────────────────
func _choice_style_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.06, 0.18, 0.90)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.42, 0.35, 0.68, 0.70)
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_right = 6
	s.corner_radius_bottom_left = 6
	s.content_margin_left = 14.0
	s.content_margin_top = 8.0
	s.content_margin_right = 14.0
	s.content_margin_bottom = 8.0
	return s

func _choice_style_hover() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.16, 0.12, 0.32, 1.0)
	s.border_width_left = 2
	s.border_width_top = 2
	s.border_width_right = 2
	s.border_width_bottom = 2
	s.border_color = Color(0.65, 0.50, 1.00, 1.0)
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_right = 6
	s.corner_radius_bottom_left = 6
	s.content_margin_left = 14.0
	s.content_margin_top = 8.0
	s.content_margin_right = 14.0
	s.content_margin_bottom = 8.0
	return s

func _choice_style_pressed() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.08, 0.22, 1.0)
	s.border_width_left = 1
	s.border_width_top = 1
	s.border_width_right = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.50, 0.40, 0.80, 1.0)
	s.corner_radius_top_left = 6
	s.corner_radius_top_right = 6
	s.corner_radius_bottom_right = 6
	s.corner_radius_bottom_left = 6
	s.content_margin_left = 14.0
	s.content_margin_top = 10.0
	s.content_margin_right = 14.0
	s.content_margin_bottom = 6.0
	return s
