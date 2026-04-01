extends Node

# Programmatic SFX using AudioStreamWAV
var players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS = 12

var _ambient_player: AudioStreamPlayer = null
var _ambient_playing: bool = false

func _ready() -> void:
	for i in MAX_PLAYERS:
		var p = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	# Dedicated ambient player (looping, separate from pool)
	_ambient_player = AudioStreamPlayer.new()
	add_child(_ambient_player)

func _get_player() -> AudioStreamPlayer:
	for p in players:
		if not p.playing:
			return p
	return players[0]

# ---------------------------------------------------------------------------
# Combat SFX
# ---------------------------------------------------------------------------

func play_hit() -> void:
	_play_tone(200.0, 0.08, -6.0)

func play_block() -> void:
	_play_tone(400.0, 0.06, -10.0)

func play_heal() -> void:
	_play_tone(600.0, 0.12, -10.0)
	await get_tree().create_timer(0.06).timeout
	_play_tone(800.0, 0.1, -10.0)

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

func play_corruption() -> void:
	_play_tone(100.0, 0.15, -8.0)

# ---------------------------------------------------------------------------
# Card type sounds
# ---------------------------------------------------------------------------

## Generic fallback (kept for backwards-compat RPC calls)
func play_card() -> void:
	_play_tone(500.0, 0.04, -12.0)

## Aggressive low tone for attack cards
func play_card_attack() -> void:
	_play_tone(175.0, 0.09, -8.0)

## Smooth mid tone for skill cards
func play_card_skill() -> void:
	_play_tone(350.0, 0.12, -10.0)

## Resonant layered chord for power cards
func play_card_power() -> void:
	_play_chord(200.0, 300.0, 0.2, -8.0)

## Dissonant low growl for curse cards
func play_card_curse() -> void:
	_play_tone(95.0, 0.18, -6.0)

# ---------------------------------------------------------------------------
# Boss / Elite encounter sounds
# ---------------------------------------------------------------------------

## Dramatic descending sequence: 500 -> 400 -> 300 -> 200 Hz
func play_boss_intro() -> void:
	_play_tone(500.0, 0.15, -4.0)
	await get_tree().create_timer(0.15).timeout
	_play_tone(400.0, 0.15, -4.0)
	await get_tree().create_timer(0.15).timeout
	_play_tone(300.0, 0.15, -4.0)
	await get_tree().create_timer(0.15).timeout
	_play_tone(200.0, 0.25, -4.0)

## Two-tone alert for elite encounters
func play_elite_intro() -> void:
	_play_tone(300.0, 0.1, -6.0)
	await get_tree().create_timer(0.12).timeout
	_play_tone(450.0, 0.18, -6.0)

# ---------------------------------------------------------------------------
# UI feedback sounds
# ---------------------------------------------------------------------------

func play_button_hover() -> void:
	_play_tone(800.0, 0.03, -22.0)

func play_button_click() -> void:
	_play_tone(600.0, 0.05, -16.0)

func play_button() -> void:
	play_button_click()

## Bright coin jingle: two quick rising tones
func play_gold_gain() -> void:
	_play_tone(1000.0, 0.08, -10.0)
	await get_tree().create_timer(0.08).timeout
	_play_tone(1200.0, 0.08, -10.0)

## Soft high-frequency card draw whoosh
func play_card_draw() -> void:
	_play_noise_burst(0.06, 12000.0, -16.0)

## Magical ascending three-tone relic fanfare: 300 -> 500 -> 700 Hz
func play_relic_acquire() -> void:
	_play_tone(300.0, 0.1, -8.0)
	await get_tree().create_timer(0.1).timeout
	_play_tone(500.0, 0.1, -8.0)
	await get_tree().create_timer(0.1).timeout
	_play_tone(700.0, 0.18, -8.0)

# ---------------------------------------------------------------------------
# Ambient / atmosphere
# ---------------------------------------------------------------------------

## Very quiet continuous drone at 60 Hz.  Call once when entering combat.
func play_ambient_hum() -> void:
	if _ambient_playing:
		return
	_ambient_playing = true
	var sample_rate = 22050
	var duration = 2.0  # looping buffer length
	var num_samples = int(sample_rate * duration)

	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.loop_begin = 0
	audio.loop_end = num_samples

	var data = PackedByteArray()
	data.resize(num_samples)
	for i in num_samples:
		var t = float(i) / sample_rate
		# Gentle fade-in for first 0.2s to avoid click at loop-start
		var fade = clampf(t / 0.2, 0.0, 1.0)
		var sample = sin(t * 60.0 * TAU) * fade * 0.3
		data[i] = int((sample * 0.5 + 0.5) * 255)
	audio.data = data

	_ambient_player.stream = audio
	_ambient_player.volume_db = -28.0
	_ambient_player.play()

func stop_ambient_hum() -> void:
	_ambient_playing = false
	_ambient_player.stop()

# ---------------------------------------------------------------------------
# Core tone generators
# ---------------------------------------------------------------------------

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

## Generate a buffer combining two frequencies (chord / layered sound).
func _play_chord(freq1: float, freq2: float, duration: float, volume_db: float = -6.0) -> void:
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
		var envelope = 1.0 - (float(i) / num_samples)
		# Sum two sine waves then normalise to [-1, 1]
		var sample = (sin(t * freq1 * TAU) + sin(t * freq2 * TAU)) * 0.5
		sample *= envelope
		data[i] = int((sample * 0.5 + 0.5) * 255)

	audio.data = data

	var player = _get_player()
	player.stream = audio
	player.volume_db = volume_db
	player.play()

## High-frequency filtered noise burst simulating a whoosh / card draw.
## cutoff_hz controls how high the random samples are pitched by sub-sampling.
func _play_noise_burst(duration: float, cutoff_hz: float, volume_db: float = -12.0) -> void:
	var sample_rate = 22050
	var num_samples = int(sample_rate * duration)

	# Step size for sub-sampling: higher cutoff_hz = finer stepping = brighter
	var step = maxi(1, int(sample_rate / cutoff_hz))

	var audio = AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data = PackedByteArray()
	data.resize(num_samples)

	var current_noise = 0.0
	for i in num_samples:
		if i % step == 0:
			current_noise = randf_range(-1.0, 1.0)
		var t = float(i) / num_samples
		# Short attack, quick decay — whoosh shape
		var envelope = t * (1.0 - t) * 4.0
		var sample = current_noise * envelope
		data[i] = int((sample * 0.5 + 0.5) * 255)

	audio.data = data

	var player = _get_player()
	player.stream = audio
	player.volume_db = volume_db
	player.play()
