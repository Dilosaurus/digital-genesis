extends Node

# Programmatic SFX using AudioStreamPlayer
var players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS = 8

func _ready() -> void:
	for i in MAX_PLAYERS:
		var p = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func _get_player() -> AudioStreamPlayer:
	for p in players:
		if not p.playing:
			return p
	return players[0]

func play_hit() -> void:
	_play_tone(200.0, 0.08, -6.0)

func play_block() -> void:
	_play_tone(400.0, 0.06, -10.0)

func play_heal() -> void:
	_play_tone(600.0, 0.12, -10.0)
	await get_tree().create_timer(0.06).timeout
	_play_tone(800.0, 0.1, -10.0)

func play_card() -> void:
	_play_tone(500.0, 0.04, -12.0)

func play_death() -> void:
	_play_tone(150.0, 0.3, -4.0)

func play_victory() -> void:
	_play_tone(523.0, 0.15, -8.0)
	await get_tree().create_timer(0.15).timeout
	_play_tone(659.0, 0.15, -8.0)
	await get_tree().create_timer(0.15).timeout
	_play_tone(784.0, 0.25, -8.0)

func play_defeat() -> void:
	_play_tone(300.0, 0.2, -6.0)
	await get_tree().create_timer(0.2).timeout
	_play_tone(200.0, 0.3, -6.0)

func play_button() -> void:
	_play_tone(440.0, 0.03, -15.0)

func play_corruption() -> void:
	_play_tone(100.0, 0.15, -8.0)

func _play_tone(freq: float, duration: float, volume_db: float = -6.0) -> void:
	var sample_rate = 22050
	var num_samples = int(sample_rate * duration)
	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(num_samples)

	for i in num_samples:
		var t = float(i) / sample_rate
		var envelope = 1.0 - (float(i) / num_samples)  # Linear decay
		var sample = sin(t * freq * TAU) * envelope
		# Add slight noise for texture
		sample += randf_range(-0.05, 0.05) * envelope
		data[i] = int((sample * 0.5 + 0.5) * 255)

	audio.data = data

	var player = _get_player()
	player.stream = audio
	player.volume_db = volume_db
	player.play()
