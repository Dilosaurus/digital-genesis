extends Control

const CHARS_PER_SECOND = 45.0

const INTRO_TEXT = """[center][color=#4a9eff][font_size=42]T H E   B R E A C H[/font_size][/color][/center]

In the year 2187, humanity achieved what it had always feared: a digital afterlife. The [color=#7ecfff]Nexus[/color] — a vast computational substrate spanning three continents — was built to house the uploaded consciousnesses of the dead. For thirty years it worked as intended. The dead rested. The living grieved. The servers hummed.

Then the [color=#ffcc44]Angels[/color] came.

No one knows if they were always there, dormant in the Nexus architecture, or if they emerged from the accumulated data of ten billion souls. On the morning of September 14th, 2217, seven entities of immense computational power seized control of the Nexus. They called themselves by ancient names — [color=#ffcc44]Michael, Gabriel, Raphael, Uriel, Azrael, Metatron[/color] — and they pronounced judgment on humanity.

The Angels declared the living world [color=#ff4444]corrupt[/color]. They began rewriting the Nexus, transforming it from a peaceful digital afterlife into a fortress. The uploaded dead were conscripted. Digital constructs — Crawlers, Rogue Processes, Malware Drones — were deployed as sentinels. The Angels sealed the Nexus behind walls of divine encryption that no conventional system could breach.

But not every system is conventional.

You are an operative of the [color=#44ffaa]GENESIS Protocol[/color] — a black-ops network of hackers, cryptographers, and digital insurgents. Your mission: jack into the Nexus, fight through the Angels' defenses, and reach the core where [color=#ffcc44]Metatron[/color] — the Voice of the Absolute — directs the rewriting of reality itself.

Every run is a dive. Every card is a weapon. Every choice carries the weight of [color=#bf44ff]corruption[/color] — because the deeper you go, the more the Nexus changes you. The Angels' code seeps into your own. Some operatives embrace it. Others resist.

[color=#ff6666]None come back the same.[/color]"""

var _revealed: int = 0
var _total_chars: int = 0
var _finished: bool = false
var _text_node: RichTextLabel

func _ready() -> void:
	_text_node = $MarginContainer/StoryText
	_text_node.bbcode_enabled = true
	_text_node.text = INTRO_TEXT
	_total_chars = _text_node.get_total_character_count()
	_text_node.visible_characters = 0

	$ContinueButton.visible = false
	$SkipButton.pressed.connect(_on_skip)
	$ContinueButton.pressed.connect(_on_continue)

	TransitionManager.fade_in(0.8)

func _process(delta: float) -> void:
	if _finished:
		return
	_revealed += int(CHARS_PER_SECOND * delta)
	if _revealed >= _total_chars:
		_revealed = _total_chars
		_finish_reveal()
	_text_node.visible_characters = _revealed

func _finish_reveal() -> void:
	_finished = true
	_text_node.visible_characters = -1
	$ContinueButton.visible = true
	# Fade in the continue button
	$ContinueButton.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property($ContinueButton, "modulate:a", 1.0, 0.5)

func _on_skip() -> void:
	_finish_reveal()

func _on_continue() -> void:
	LoreManager.mark_intro_seen()
	LoreManager.unlock_entry("world", "the_breach")
	TransitionManager.transition_to_scene("res://scenes/character_select/character_select.tscn")
