extends Control

signal tithe_choice_made(accepted: bool)

@onready var title_label: Label = $Panel/TitleLabel
@onready var desc_label: Label = $Panel/DescLabel
@onready var accept_btn: Button = $Panel/AcceptButton
@onready var refuse_btn: Button = $Panel/RefuseButton

func _ready() -> void:
	visible = false
	accept_btn.pressed.connect(func(): tithe_choice_made.emit(true); visible = false)
	refuse_btn.pressed.connect(func(): tithe_choice_made.emit(false); visible = false)

func show_tithe(cost: int, player_count: int) -> void:
	var per_player = maxi(int(cost / player_count), 1)
	title_label.text = ">> BLOOD TITHE <<"
	desc_label.text = "The heavens demand sacrifice.\nPay %d HP (%d each) or lose cards." % [cost, per_player]
	visible = true
