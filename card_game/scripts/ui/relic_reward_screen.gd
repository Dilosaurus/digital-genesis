extends Control

signal relic_chosen(relic_id: String)

@onready var title_label: Label = $Panel/TitleLabel
@onready var relic_container: VBoxContainer = $Panel/RelicContainer

func _ready() -> void:
	visible = false

func show_relics(relic_ids: Array[String]) -> void:
	for child in relic_container.get_children():
		child.queue_free()

	title_label.text = "CHOOSE A RELIC"

	for rid in relic_ids:
		var relic = RelicSystem.get_relic(rid)
		if not relic:
			continue
		var btn = Button.new()
		btn.text = "%s — %s" % [relic.display_name, relic.description]
		btn.custom_minimum_size = Vector2(400, 40)
		btn.pressed.connect(func():
			visible = false
			relic_chosen.emit(rid)
		)
		relic_container.add_child(btn)

	var skip_btn = Button.new()
	skip_btn.text = "Skip"
	skip_btn.custom_minimum_size = Vector2(400, 35)
	skip_btn.pressed.connect(func():
		visible = false
		relic_chosen.emit("")
	)
	relic_container.add_child(skip_btn)

	visible = true
