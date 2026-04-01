extends Control

signal event_completed

const EVENTS = [
	{
		"title": "Corrupted Terminal",
		"description": "A flickering terminal offers forbidden knowledge...",
		"choices": [
			{"text": "Access the data (+1 random card, +10 corruption)", "effect": "card_and_corruption"},
			{"text": "Purge the terminal (Heal 15 HP)", "effect": "heal"},
			{"text": "Walk away", "effect": "nothing"},
		]
	},
	{
		"title": "Fallen Angel's Cache",
		"description": "You find a stash left by a destroyed angel...",
		"choices": [
			{"text": "Take the gold (+50 gold)", "effect": "gold"},
			{"text": "Take the artifact (random card)", "effect": "card"},
			{"text": "Absorb residual energy (+5 max HP)", "effect": "max_hp"},
		]
	},
	{
		"title": "The Shrine of Sin",
		"description": "A dark altar pulses with malevolent energy...",
		"choices": [
			{"text": "Pray at the shrine (Remove a card)", "effect": "remove_card"},
			{"text": "Defile the shrine (+2 Strength start, +15 corruption)", "effect": "strength_corruption"},
			{"text": "Ignore it", "effect": "nothing"},
		]
	},
	{
		"title": "Digital Fountain",
		"description": "Pure data streams cascade like water...",
		"choices": [
			{"text": "Drink deeply (Heal to full, +20 corruption)", "effect": "full_heal_corruption"},
			{"text": "Wash your code (Remove all corruption)", "effect": "purify"},
			{"text": "Fill a container (Gain 30 gold)", "effect": "gold_small"},
		]
	},
	{
		"title": "Ghost in the Machine",
		"description": "A spectral process offers you a deal...",
		"choices": [
			{"text": "Accept the deal (Gain 2 random cards)", "effect": "two_cards"},
			{"text": "Consume it (+10 max HP, lose 1 card)", "effect": "hp_lose_card"},
			{"text": "Decline", "effect": "nothing"},
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
		btn.custom_minimum_size = Vector2(440, 40)
		btn.pressed.connect(_on_choice.bind(choice["effect"]))
		$Panel/ChoiceContainer.add_child(btn)

	visible = true

func _on_choice(effect: String) -> void:
	var run = GameManager.current_run
	if not run:
		visible = false
		event_completed.emit()
		return

	var all_cards = GameManager.card_database.keys()
	var playable_cards: Array[String] = []
	for cid in all_cards:
		var cd = GameManager.get_card_data(cid)
		if cd and not cd.id.begins_with("curse_") and cd.energy_cost < 4:
			playable_cards.append(cid)

	match effect:
		"card_and_corruption":
			if playable_cards.size() > 0:
				run.add_card(playable_cards[randi() % playable_cards.size()])
			# corruption applied at next combat start
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
			pass  # Applied at combat start
		"full_heal_corruption":
			run.current_hp = run.max_hp
		"purify":
			pass  # Corruption reset applied at next combat
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

	visible = false
	event_completed.emit()
