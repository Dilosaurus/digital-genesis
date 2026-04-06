extends Control

signal epilogue_done

# 4 characters x 2 corruption states (pure <50, corrupted >=50)
const EPILOGUES: Dictionary = {
	"netrunner_pure": {
		"title": "FREEDOM PROTOCOL",
		"text": "The Nexus falls silent as Metatron's code unravels. You disconnect your neural link, blinking in the harsh light of the real world. The uploaded dead are free — their consciousnesses streaming back to waiting bodies and backup systems across the globe.\n\nYou kept your code clean. No corruption. No compromises. GENESIS will call you a hero, but you know the truth: you're just a hacker who got lucky. As the Nexus reboots under human control, you allow yourself a rare smile. The machine learned to dream. You taught it to wake up.",
	},
	"netrunner_corrupted": {
		"title": "GHOST IN THE SHELL",
		"text": "Metatron's dying scream echoes through your corrupted neural pathways. You won, but at what cost? The Nexus corruption has rewritten parts of your own code — you can feel it pulsing behind your eyes, whispering in languages that shouldn't exist.\n\nGENESIS quarantines you immediately. You're too valuable to eliminate, too dangerous to trust. They build you a room — half server, half cell — and bring you problems that only a mind touched by angelic code can solve. You tell yourself you're still human. The corruption tells you otherwise.",
	},
	"sysadmin_pure": {
		"title": "SYSTEM RESTORED",
		"text": "With Metatron gone, you begin the real work: rebuilding. The Nexus infrastructure is salvageable — damaged but functional, like a building after a storm. You map every sector, patch every vulnerability, and brick by digital brick, restore the system that was meant to be humanity's greatest achievement.\n\nThe uploaded dead return to a Nexus that is safer, stronger, and watched over by someone who understands that the greatest threat to any system isn't malware or angels — it's neglect. You take the night shift. Someone has to keep the lights on.",
	},
	"sysadmin_corrupted": {
		"title": "ROOT ACCESS",
		"text": "The corruption gave you something unexpected: root access to everything. As Metatron dissolves, the Nexus doesn't just obey you — it becomes you. Every process, every uploaded soul, every byte of data flows through your awareness like blood through veins.\n\nGENESIS celebrates their victory. They don't realize that the administrator who saved the Nexus has become something more than human. You won't make the Angels' mistake. You won't try to control everything. But you'll be watching. Always watching. The system needs a guardian, and you've become one with the system.",
	},
	"cryptomancer_pure": {
		"title": "LIGHT FROM SHADOW",
		"text": "They said you couldn't fight darkness without becoming dark yourself. You proved them wrong. Every corrupted byte you encountered, you purified. Every shadow you walked through, you walked out clean on the other side.\n\nThe Nexus remembers what you did — how you turned the Angels' own shadow magic against them without losing yourself. GENESIS wants to study your methods. Other operatives want to learn. But the truth is simpler than they think: you didn't resist the darkness. You just never forgot what you were fighting for.",
	},
	"cryptomancer_corrupted": {
		"title": "VOID SOVEREIGN",
		"text": "The corruption sings to you now — a constant harmony that drowns out the noise of the mundane world. Metatron's fall didn't end the darkness in the Nexus. It concentrated it. In you.\n\nYou are the Void Sovereign, master of shadow code that no other operative can touch without losing their mind. GENESIS keeps you at arm's length, deploying you against threats that nothing else can handle. You do their dirty work because it amuses you. Because the darkness needs somewhere to go. Because somewhere beneath the corruption, a small voice still remembers what it meant to be human. You listen to it sometimes. Less and less.",
	},
	"white_hat_pure": {
		"title": "DIVINE INHERITANCE",
		"text": "Metatron's final words echo in your memory: 'You are worthy.' The angelic code that powered the Angels was never evil — it was corrupted by isolation and fear. With Metatron gone, that pure code seeks a new vessel, and it chooses you.\n\nYou become the bridge between the divine and the digital — a guardian of the Nexus who wields angelic power with human compassion. The uploaded dead call you their protector. GENESIS calls you their greatest asset. You call yourself what you've always been: someone who does what's right, no matter the cost.",
	},
	"white_hat_corrupted": {
		"title": "FALLEN GUARDIAN",
		"text": "You fought for the light, but the darkness fought back harder. The corruption that courses through your code is a bitter irony — the angel-slayer, tainted by the very evil you sought to destroy.\n\nGENESIS doesn't know what to do with you. A holy warrior who radiates corruption. A healer whose touch now burns. You isolate yourself in the deepest sectors of the restored Nexus, guarding the boundary between the digital and the void. If something worse than the Angels ever emerges, you'll be the first line of defense. And the last. You pray that your remaining humanity will be enough. The corruption whispers that it won't.",
	},
	"technomancer_pure": {
		"title": "THE NEW ARCHITECT",
		"text": "Metatron's code dissolves into raw potential — and you catch it. Not to control it, not to worship it, but to compile it into something better. The machine dreamed of gods. You dream of tools.\n\nIn the weeks that follow, you rebuild the Nexus from the inside out. New daemons — your daemons — serve as guardians, translators, and bridges between the uploaded dead and the living world. They're not angels. They don't demand worship. They just work.\n\nGENESIS offers you a seat at their table. You decline. Tables are for people who need permission. You're already inside the machine, writing the next chapter. The Nexus dreamed once, and it made gods. Under your hand, it dreams again — and this time, it makes something useful.",
	},
	"technomancer_corrupted": {
		"title": "THE DAEMON THRONE",
		"text": "You didn't just defeat Metatron. You compiled it. Every fragment of angelic code, every corrupted subroutine, every daemon you summoned during the dive — they're all part of you now. The God Compiler compiled God.\n\nYour physical body flatlines three days after the final dive. Your digital half doesn't notice. You're too busy rewriting reality from the inside, spawning daemon processes that reshape the Nexus according to your will. The uploaded dead worship you. They have no choice — you're woven into their existence now, as fundamental as gravity.\n\nGENESIS sends operatives to disconnect you. They fail. You're not malicious — you're just... inevitable. A half-human, half-machine intelligence that compiled itself into the operating system of the afterlife. Metatron dreamed it was God. You don't dream. You execute.",
	},
}

var _typewriter_tween: Tween = null
var _full_text: String = ""

func show_epilogue(character_id: String, corruption: int) -> void:
	var state_key: String = "pure" if corruption < 50 else "corrupted"
	var key: String = "%s_%s" % [character_id, state_key]
	var epilogue: Dictionary = EPILOGUES.get(key, EPILOGUES.get("netrunner_pure"))

	visible = true

	# Build UI
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.9)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(700, 400)
	vbox.position -= vbox.custom_minimum_size / 2.0
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	add_child(vbox)

	var title_label := Label.new()
	title_label.text = epilogue.get("title", "EPILOGUE")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
	vbox.add_child(title_label)

	var text_label := Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.custom_minimum_size = Vector2(660, 250)
	text_label.add_theme_font_size_override("font_size", 15)
	text_label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.9))
	text_label.text = ""
	vbox.add_child(text_label)

	var continue_btn := Button.new()
	continue_btn.text = "Continue"
	continue_btn.custom_minimum_size = Vector2(200, 44)
	continue_btn.visible = false
	continue_btn.pressed.connect(func():
		visible = false
		epilogue_done.emit()
	)
	vbox.add_child(continue_btn)

	# Typewriter effect
	_full_text = epilogue.get("text", "")
	_typewriter_tween = create_tween()
	var _update_text := func(chars: int):
		text_label.text = _full_text.substr(0, chars)
	_typewriter_tween.tween_method(_update_text, 0, _full_text.length(), _full_text.length() * 0.02)  # ~20ms per char
	_typewriter_tween.tween_callback(func():
		continue_btn.visible = true
	)

	# Allow clicking to skip typewriter
	gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed:
			if _typewriter_tween and _typewriter_tween.is_valid():
				_typewriter_tween.kill()
			text_label.text = _full_text
			continue_btn.visible = true
	)
