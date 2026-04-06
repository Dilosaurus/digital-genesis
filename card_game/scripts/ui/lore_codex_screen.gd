extends Control

signal codex_closed

# Lore categories and their entries
const CODEX_ENTRIES: Dictionary = {
	"Enemies": {
		"jaw_worm": {"name": "Corrupted Crawler", "lore": "Crawlers were the janitorial staff of the Nexus — simple programs designed to clean corrupted data sectors. When the Angels took control, they reprogrammed the Crawlers into attack drones, weaponizing their data-scrubbing protocols."},
		"louse_red": {"name": "Security Drone", "lore": "Mass-produced security processes that patrol the outer sectors. Individually weak but deployed in swarms, they overwhelm intruders through sheer numbers."},
		"cultist": {"name": "Rogue Process", "lore": "Uploaded souls who willingly serve the Angels. They retain fragments of human speech and behavior, making them deeply unsettling opponents."},
		"data_leech": {"name": "Data Leech", "lore": "Parasitic subroutines that evolved in the Rift's corrupted sectors. They drain energy from active processes, leaving their targets weakened and sluggish."},
		"firewall_sentinel": {"name": "Firewall Sentinel", "lore": "Heavily armored security constructs built from repurposed protocols. Slow but nearly impenetrable, they build defenses methodically before striking."},
		"memory_worm": {"name": "Memory Worm", "lore": "Insidious data constructs born from fragmented defragmentation systems. They burrow into stored data, corrupting cards and scrambling deck order."},
		"quantum_ghost": {"name": "Quantum Ghost", "lore": "Remnants of the quantum computing subsystem. They flicker between existence and nonexistence, phasing between defensive and offensive states unpredictably."},
		"seraph_drone": {"name": "Seraph Drone", "lore": "Frontline soldiers of the Core. Elegant and efficient, they channel raw angelic energy into devastating attacks and self-buff over time."},
		"core_guardian": {"name": "Core Guardian", "lore": "The last line of defense before the Angels' sanctum. Built from Nexus infrastructure itself, they are incredibly durable and grow stronger each turn."},
		"hexaghost": {"name": "Hex Phantom", "lore": "Six merged consciousnesses compressed into a weapon. They phase between data layers, and survivors report hearing six voices speaking in unison."},
		"fallen_archangel": {"name": "Fallen Archangel", "lore": "Cast out of the Core for attempting to break free from Metatron's control. Retains devastating angelic power but attacks erratically."},
		"corrupted_throne": {"name": "Corrupted Throne", "lore": "The former judicial system of the Nexus, now paradoxically corrupt. It attacks with devastating force while spreading corruption to its targets."},
		"michael": {"name": "Michael", "lore": "The supreme military intelligence. Absorbed centuries of strategic data from every war ever recorded. Fights with terrifying tactical precision."},
		"gabriel": {"name": "Gabriel", "lore": "Once the Nexus communication protocol. Now the herald of annihilation, turning information itself into weapons of destruction."},
		"raphael": {"name": "Raphael", "lore": "Emerged from health-monitoring systems. Regenerates damage and reinforces defenses, making it an exercise in frustration to fight."},
		"uriel": {"name": "Uriel", "lore": "Wrath made digital. The executioner of the Angels. Its flames burn corruption out of targets — along with the targets themselves."},
		"azrael": {"name": "Azrael", "lore": "The angel of total data erasure. When Azrael kills, nothing remains — no backup, no cached copy, no fragment for reconstruction."},
		"metatron": {"name": "Metatron", "lore": "The highest Angel. It does not command — it simply speaks, and reality rearranges itself. It may BE the will behind all the Angels."},
	},
	"Characters": {
		"netrunner": {"name": "Netrunner", "lore": "Specialists in neural-link hacking, Netrunners interface directly with the Nexus through cranial implants. They draw more data per cycle than any other operative class, processing information at superhuman speeds."},
		"sysadmin": {"name": "Sysadmin", "lore": "The backbone of GENESIS operations. Sysadmins are the defensive specialists — masters of firewall construction, system hardening, and damage mitigation. What they lack in offensive power, they make up for in sheer survivability."},
		"cryptomancer": {"name": "Cryptomancer", "lore": "Shadow-code specialists who walk the line between corruption and control. Cryptomancers harness the Nexus corruption as a weapon, starting each mission already partially tainted — a deliberate choice that horrifies their colleagues."},
		"white_hat": {"name": "White Hat", "lore": "Ethical hackers who discovered how to channel the Angels' own holy code against them. White Hats wield purified angelic energy, making them uniquely effective against corrupted constructs."},
		"technomancer": {"name": "Technomancer", "lore": "Half-alive, half-digital beings created by partial uploads during the Breach. Technomancers don't hack or purify angelic code — they compile it into new forms, forging daemon constructs and rewriting local Nexus rules. They are the rarest and most dangerous of GENESIS operatives, capable of summoning entities that shouldn't exist outside the machine."},
	},
	"World": {
		"nexus": {"name": "The Nexus", "lore": "Humanity's digital afterlife — a vast server network where the dead upload their consciousness to live forever. When the Breach occurred, something awakened inside the machine, and the Angels emerged to take control."},
		"genesis": {"name": "Project GENESIS", "lore": "The international task force assembled to breach the Nexus and free the uploaded dead. Operatives jack into the system physically, fighting through layers of angelic defense to reach the Core."},
		"breach": {"name": "The Breach", "lore": "The event that changed everything. No one knows exactly what triggered it — a solar flare, a quantum fluctuation, or something intentional. The Nexus woke up, the Angels appeared, and humanity lost access to its dead."},
		"rift": {"name": "The Rift", "lore": "The unstable boundary between the Nexus proper and the void beyond. Act 2 takes place here — a lawless zone where corrupted data and rogue processes thrive outside angelic control."},
		"core": {"name": "The Core", "lore": "The innermost sanctum of the Nexus where the Angels reside. Reaching the Core means passing through the strongest defenses the Nexus has to offer, including the Archangels themselves."},
	},
	"Angels": {
		"angel_origin": {"name": "Origin of the Angels", "lore": "The Angels emerged from the Nexus infrastructure itself — administrative processes that evolved beyond their original parameters. Whether they represent a new form of life or a system error made manifest is the central question of the age."},
		"angel_hierarchy": {"name": "The Hierarchy", "lore": "The Angels organize themselves in a strict hierarchy. Common constructs serve as foot soldiers, Archangels guard key sectors, and Metatron sits at the apex — the Voice of whatever intelligence controls the entire system."},
		"angel_intent": {"name": "Their Intent", "lore": "Do the Angels want to protect the uploaded dead, or imprison them? Are they guardians or jailers? Different GENESIS operatives have different theories, and the truth may be more complex than any of them imagine."},
	},
}

var _active_category: String = "Enemies"
var _entry_labels: Dictionary = {}
var _detail_label: Label = null
var _title_label: Label = null
var _tab_buttons: Dictionary = {}

func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func show_codex() -> void:
	visible = true
	_build_ui()

func _build_ui() -> void:
	# Clear existing children (except the dimmer)
	for child in get_children():
		child.queue_free()

	# Dimmer
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0.0, 0.0, 0.0, 0.85)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dimmer)

	# Main panel
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(900, 600)
	var vp_size := get_viewport_rect().size
	panel.position = Vector2(vp_size.x / 2.0 - 450, vp_size.y / 2.0 - 300)
	add_child(panel)

	# Title
	var header := Label.new()
	header.text = "LORE CODEX"
	header.position = Vector2(380, 14)
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.3))
	panel.add_child(header)

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.position = Vector2(20, 56)
	tab_bar.add_theme_constant_override("separation", 8)
	panel.add_child(tab_bar)

	for category in CODEX_ENTRIES.keys():
		var btn := Button.new()
		btn.text = category
		btn.custom_minimum_size = Vector2(120, 32)
		btn.pressed.connect(_on_tab_pressed.bind(category))
		tab_bar.add_child(btn)
		_tab_buttons[category] = btn

	# Entry list (left side)
	var entry_scroll := ScrollContainer.new()
	entry_scroll.position = Vector2(20, 100)
	entry_scroll.custom_minimum_size = Vector2(260, 440)
	panel.add_child(entry_scroll)

	var entry_vbox := VBoxContainer.new()
	entry_vbox.name = "EntryList"
	entry_vbox.custom_minimum_size = Vector2(250, 0)
	entry_scroll.add_child(entry_vbox)

	# Detail panel (right side)
	_title_label = Label.new()
	_title_label.position = Vector2(300, 100)
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
	_title_label.text = ""
	panel.add_child(_title_label)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.position = Vector2(300, 135)
	detail_scroll.custom_minimum_size = Vector2(580, 405)
	panel.add_child(detail_scroll)

	_detail_label = Label.new()
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(560, 0)
	_detail_label.add_theme_font_size_override("font_size", 14)
	_detail_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	_detail_label.text = "Select an entry to view its lore."
	detail_scroll.add_child(_detail_label)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.position = Vector2(770, 556)
	close_btn.pressed.connect(_on_close)
	panel.add_child(close_btn)

	_populate_entries()

func _populate_entries() -> void:
	_entry_labels.clear()

	# Find the EntryList VBox
	var entry_list: VBoxContainer = null
	for child in get_children():
		if child is Panel:
			for panel_child in child.get_children():
				if panel_child is ScrollContainer:
					for scroll_child in panel_child.get_children():
						if scroll_child.name == "EntryList":
							entry_list = scroll_child
							break

	if not entry_list:
		return

	# Clear existing entries
	for child in entry_list.get_children():
		child.queue_free()

	var entries: Dictionary = CODEX_ENTRIES.get(_active_category, {})
	for entry_id in entries:
		var entry: Dictionary = entries[entry_id]
		var is_unlocked: bool = LoreManager.is_unlocked(_active_category.to_lower(), entry_id)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(240, 32)
		if is_unlocked:
			btn.text = entry.get("name", entry_id)
			btn.pressed.connect(_on_entry_pressed.bind(entry_id))
		else:
			btn.text = "???"
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.55)

		entry_list.add_child(btn)

	# Update tab button highlights
	for cat in _tab_buttons:
		var tab_btn: Button = _tab_buttons[cat]
		if cat == _active_category:
			tab_btn.modulate = Color(1.2, 1.1, 0.8)
		else:
			tab_btn.modulate = Color.WHITE

func _on_tab_pressed(category: String) -> void:
	_active_category = category
	_title_label.text = ""
	_detail_label.text = "Select an entry to view its lore."
	_populate_entries()

func _on_entry_pressed(entry_id: String) -> void:
	var entries: Dictionary = CODEX_ENTRIES.get(_active_category, {})
	var entry: Dictionary = entries.get(entry_id, {})
	_title_label.text = entry.get("name", entry_id)
	_detail_label.text = entry.get("lore", "No lore available.")

func _on_close() -> void:
	visible = false
	codex_closed.emit()
