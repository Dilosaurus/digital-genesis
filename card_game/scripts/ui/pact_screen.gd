extends Control

signal pact_resolved(accepted: bool)

@onready var title_label: Label = $Panel/TitleLabel
@onready var pact_name_label: Label = $Panel/PactNameLabel
@onready var desc_label: Label = $Panel/DescLabel
@onready var accept_btn: Button = $Panel/AcceptButton
@onready var decline_btn: Button = $Panel/DeclineButton

var current_pact: Dictionary = {}

func _ready() -> void:
	visible = false
	accept_btn.pressed.connect(_on_accept)
	decline_btn.pressed.connect(_on_decline)

func show_pact(pact: Dictionary) -> void:
	current_pact = pact
	title_label.text = ">> INFERNAL PACT <<"
	pact_name_label.text = pact["title"]
	pact_name_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.1))
	desc_label.text = pact["description"]
	visible = true

func _on_accept() -> void:
	visible = false
	pact_resolved.emit(true)

func _on_decline() -> void:
	visible = false
	pact_resolved.emit(false)
