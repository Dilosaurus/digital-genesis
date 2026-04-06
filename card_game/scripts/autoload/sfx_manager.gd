extends Node

# Real SFX using Kenney audio packs (CC0 licensed)
# Pools AudioStreamPlayer nodes and picks from sound variants randomly.
# Boss sounds use horror/creature packs routed through "Boss" audio bus
# with reverb + low-pass for cavernous otherworldly feel.

var players: Array[AudioStreamPlayer] = []
const MAX_PLAYERS = 16  # bumped for layered sounds

var _ambient_player: AudioStreamPlayer = null
var _ambient_playing: bool = false

# Preloaded sound banks — each key maps to an array of AudioStream for variety
var _sounds: Dictionary = {}

# Pitch randomization range (semitone-ish). Boss sounds get wider range.
const PITCH_RANDOM_RANGE := 0.08       # ±8% for normal sounds
const BOSS_PITCH_RANDOM_RANGE := 0.12  # ±12% for boss sounds — more unhinged

# Boss phase pitch shift — gets deeper as boss weakens
# Set this from gameplay code: SFXManager.boss_pitch_shift = -0.15
var boss_pitch_shift: float = 0.0

func _ready() -> void:
	for i in MAX_PLAYERS:
		var p = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	_ambient_player = AudioStreamPlayer.new()
	add_child(_ambient_player)
	_load_sounds()

func _load_sounds() -> void:
	# Combat
	_sounds["hit"] = _load_variants([
		"res://assets/sfx/impact_sounds/Audio/impactMetal_light_000.ogg",
		"res://assets/sfx/impact_sounds/Audio/impactMetal_light_001.ogg",
		"res://assets/sfx/impact_sounds/Audio/impactMetal_light_002.ogg",
		"res://assets/sfx/impact_sounds/Audio/impactMetal_light_003.ogg",
	])
	_sounds["block"] = _load_variants([
		"res://assets/sfx/rpg_audio/Audio/metalClick.ogg",
		"res://assets/sfx/rpg_audio/Audio/metalLatch.ogg",
	])
	_sounds["heal"] = _load_variants([
		"res://assets/sfx/digital_audio/Audio/powerUp2.ogg",
		"res://assets/sfx/digital_audio/Audio/powerUp3.ogg",
	])
	_sounds["death"] = _load_variants([
		"res://assets/sfx/impact_sounds/Audio/impactMetal_heavy_000.ogg",
		"res://assets/sfx/impact_sounds/Audio/impactMetal_heavy_001.ogg",
		"res://assets/sfx/impact_sounds/Audio/impactMetal_heavy_002.ogg",
	])

	# Card types
	_sounds["card_attack"] = _load_variants([
		"res://assets/sfx/rpg_audio/Audio/knifeSlice.ogg",
		"res://assets/sfx/rpg_audio/Audio/knifeSlice2.ogg",
		"res://assets/sfx/rpg_audio/Audio/chop.ogg",
	])
	_sounds["card_skill"] = _load_variants([
		"res://assets/sfx/rpg_audio/Audio/cloth1.ogg",
		"res://assets/sfx/rpg_audio/Audio/cloth2.ogg",
		"res://assets/sfx/rpg_audio/Audio/cloth3.ogg",
	])
	_sounds["card_power"] = _load_variants([
		"res://assets/sfx/digital_audio/Audio/powerUp4.ogg",
		"res://assets/sfx/digital_audio/Audio/powerUp5.ogg",
	])
	_sounds["card_curse"] = _load_variants([
		"res://assets/sfx/digital_audio/Audio/lowDown.ogg",
		"res://assets/sfx/digital_audio/Audio/phaserDown1.ogg",
	])
	_sounds["card_draw"] = _load_variants([
		"res://assets/sfx/rpg_audio/Audio/bookFlip1.ogg",
		"res://assets/sfx/rpg_audio/Audio/bookFlip2.ogg",
		"res://assets/sfx/rpg_audio/Audio/bookFlip3.ogg",
	])
	_sounds["card_generic"] = _load_variants([
		"res://assets/sfx/rpg_audio/Audio/bookOpen.ogg",
	])

	# UI
	_sounds["button_click"] = _load_variants([
		"res://assets/sfx/ui_audio/Audio/click2.ogg",
		"res://assets/sfx/ui_audio/Audio/click3.ogg",
		"res://assets/sfx/ui_audio/Audio/click4.ogg",
	])
	_sounds["button_hover"] = _load_variants([
		"res://assets/sfx/ui_audio/Audio/rollover2.ogg",
		"res://assets/sfx/ui_audio/Audio/rollover3.ogg",
	])

	# Rewards / economy
	_sounds["gold_gain"] = _load_variants([
		"res://assets/sfx/rpg_audio/Audio/handleCoins.ogg",
		"res://assets/sfx/rpg_audio/Audio/handleCoins2.ogg",
	])
	_sounds["relic_acquire"] = _load_variants([
		"res://assets/sfx/interface_sounds/Audio/confirmation_001.ogg",
		"res://assets/sfx/interface_sounds/Audio/confirmation_002.ogg",
	])

	# Encounter intros
	_sounds["boss_intro"] = _load_variants([
		"res://assets/sfx/digital_audio/Audio/phaserDown2.ogg",
		"res://assets/sfx/digital_audio/Audio/phaserDown3.ogg",
	])
	_sounds["elite_intro"] = _load_variants([
		"res://assets/sfx/digital_audio/Audio/phaserUp3.ogg",
		"res://assets/sfx/digital_audio/Audio/phaserUp4.ogg",
	])

	# Win / lose
	_sounds["victory"] = _load_variants([
		"res://assets/sfx/digital_audio/Audio/threeTone2.ogg",
		"res://assets/sfx/digital_audio/Audio/zapThreeToneUp.ogg",
	])
	_sounds["defeat"] = _load_variants([
		"res://assets/sfx/digital_audio/Audio/lowThreeTone.ogg",
		"res://assets/sfx/digital_audio/Audio/zapThreeToneDown.ogg",
	])

	# Corruption
	_sounds["corruption"] = _load_variants([
		"res://assets/sfx/digital_audio/Audio/lowRandom.ogg",
		"res://assets/sfx/digital_audio/Audio/spaceTrash1.ogg",
	])

	# Boss / puppet sounds — horror + creature packs
	# Horror Sound Library (CC-BY 3.0 Little Robot Sound Factory)
	# 80 CC0 Creature SFX (CC0)
	var _h := "res://assets/sfx/horror_sounds/Horror Sound Library/Wav/"
	var _c := "res://assets/sfx/creature_sounds/"

	_sounds["boss_idle_hum"] = _load_variants([
		_c + "weird_01.ogg",      # eerie ambient creature noise
		_c + "weird_03.ogg",
		_c + "weird_05.ogg",
		_c + "breath.ogg",        # low breathing
	])
	_sounds["boss_attack_telegraph"] = _load_variants([
		_c + "monster_01.ogg",    # rising growl
		_c + "monster_03.ogg",
		_c + "roar_01.ogg",
	])
	_sounds["boss_attack_impact"] = _load_variants([
		_h + "Bonecrack_00.wav",  # BONE CRACK on impact
		_h + "Bonecrack_01.wav",
		_h + "Bonecrack_02.wav",
		_h + "Bonecrack_03.wav",
	])
	_sounds["boss_hit"] = _load_variants([
		_c + "hurt_01.ogg",       # creature pain grunt
		_c + "hurt_02.ogg",
		_c + "hurt_03.ogg",
		_c + "hurt_04.ogg",
		_c + "hurt_05.ogg",
	])
	_sounds["boss_cast"] = _load_variants([
		_c + "alien_01.ogg",      # otherworldly channeling
		_c + "alien_03.ogg",
		_c + "alien_05.ogg",
		_h + "Monster_04.wav",
	])
	_sounds["boss_summon"] = _load_variants([
		_c + "roar_02.ogg",       # deep summoning roar
		_c + "roar_03.ogg",
		_h + "Monster_00.wav",
		_h + "Monster_02.wav",
	])
	_sounds["boss_death"] = _load_variants([
		_c + "scream_01.ogg",     # death scream
		_c + "scream_02.ogg",
		_h + "Monster_05.wav",
		_h + "Monster_06.wav",
	])
	_sounds["boss_buff"] = _load_variants([
		_c + "monster_05.ogg",    # powering up growl
		_c + "monster_06.ogg",
		_c + "alien_02.ogg",
	])
	_sounds["boss_stagger"] = _load_variants([
		_c + "grunt_01.ogg",      # heavy impact grunt
		_c + "grunt_02.ogg",
		_c + "grunt_03.ogg",
		_h + "Bonecrack_02.wav",  # bone crunch on stagger
	])
	_sounds["boss_phase"] = _load_variants([
		_c + "monster_02.ogg",    # transformation scream
		_c + "monster_04.ogg",
		_c + "roar_01.ogg",
		_h + "Monster_01.wav",
		_h + "Monster_03.wav",
	])
	_sounds["boss_taunt"] = _load_variants([
		_h + "Laugh_Evil_00.wav", # EVIL LAUGH
		_h + "Laugh_Evil_01.wav",
		_h + "Laugh_Evil_02.wav",
	])
	_sounds["boss_telegraph"] = _load_variants([
		_c + "troll_01.ogg",      # menacing low growl
		_c + "troll_02.ogg",
		_c + "misc_04.ogg",
	])

func _load_variants(paths: Array) -> Array:
	var result: Array = []
	for path in paths:
		var stream = load(path)
		if stream:
			result.append(stream)
		else:
			push_warning("SFXManager: Could not load sound: %s" % path)
	return result

func _get_player() -> AudioStreamPlayer:
	for p in players:
		if not p.playing:
			return p
	# All busy — steal the oldest one
	return players[0]

func _play_sound(key: String, volume_db: float = -6.0, use_boss_bus: bool = false) -> void:
	if not _sounds.has(key) or _sounds[key].size() == 0:
		return
	var variants: Array = _sounds[key]
	var stream = variants[randi() % variants.size()]
	var player = _get_player()
	player.stream = stream
	player.volume_db = volume_db

	# Pitch randomization — slight variation every play
	var pitch_range = BOSS_PITCH_RANDOM_RANGE if use_boss_bus else PITCH_RANDOM_RANGE
	player.pitch_scale = 1.0 + randf_range(-pitch_range, pitch_range)

	# Boss phase shift — gets lower/more distorted as boss weakens
	if use_boss_bus:
		player.pitch_scale += boss_pitch_shift
		player.bus = &"Boss"
	else:
		player.bus = &"Master"

	player.play()

## Play two sounds simultaneously for a bigger, layered impact.
## [param key1] is the primary sound, [param key2] layers on top.
func _play_layered(key1: String, key2: String, vol1: float = -4.0, vol2: float = -8.0) -> void:
	_play_sound(key1, vol1, true)
	# Slight delay on the second layer for thickness (not exact overlap)
	_play_sound(key2, vol2, true)

## Play three sounds for massive moments (phase transition, death).
func _play_triple_layer(key1: String, key2: String, key3: String,
		vol1: float = -2.0, vol2: float = -6.0, vol3: float = -10.0) -> void:
	_play_sound(key1, vol1, true)
	_play_sound(key2, vol2, true)
	_play_sound(key3, vol3, true)

# ---------------------------------------------------------------------------
# Combat SFX
# ---------------------------------------------------------------------------

func play_hit() -> void:
	_play_sound("hit", -4.0)

func play_block() -> void:
	_play_sound("block", -6.0)

func play_heal() -> void:
	_play_sound("heal", -8.0)

func play_death() -> void:
	_play_sound("death", -2.0)

func play_victory() -> void:
	_play_sound("victory", -4.0)

func play_defeat() -> void:
	_play_sound("defeat", -4.0)

func play_corruption() -> void:
	_play_sound("corruption", -8.0)

# ---------------------------------------------------------------------------
# Card type sounds
# ---------------------------------------------------------------------------

func play_card() -> void:
	_play_sound("card_generic", -8.0)

func play_card_attack() -> void:
	_play_sound("card_attack", -4.0)

func play_card_skill() -> void:
	_play_sound("card_skill", -6.0)

func play_card_power() -> void:
	_play_sound("card_power", -6.0)

func play_card_curse() -> void:
	_play_sound("card_curse", -6.0)

# ---------------------------------------------------------------------------
# Boss / Elite encounter sounds
# ---------------------------------------------------------------------------

func play_boss_intro() -> void:
	_play_sound("boss_intro", -2.0, true)

func play_elite_intro() -> void:
	_play_sound("elite_intro", -4.0, true)

# ---------------------------------------------------------------------------
# UI feedback sounds
# ---------------------------------------------------------------------------

func play_button_hover() -> void:
	_play_sound("button_hover", -14.0)

func play_button_click() -> void:
	_play_sound("button_click", -8.0)

func play_button() -> void:
	play_button_click()

func play_gold_gain() -> void:
	_play_sound("gold_gain", -4.0)

func play_card_draw() -> void:
	_play_sound("card_draw", -10.0)

func play_relic_acquire() -> void:
	_play_sound("relic_acquire", -6.0)

# ---------------------------------------------------------------------------
# Boss / puppet sounds
# ---------------------------------------------------------------------------

func play_boss_idle_hum() -> void:
	_play_sound("boss_idle_hum", -18.0, true)

func play_boss_attack_telegraph() -> void:
	# Layer: growl + low alien hum underneath
	_play_layered("boss_attack_telegraph", "boss_idle_hum", -6.0, -14.0)

func play_boss_attack_impact() -> void:
	# BIG moment — bone crack + creature hurt layered for massive hit
	_play_layered("boss_attack_impact", "boss_stagger", -2.0, -8.0)

func play_boss_hit() -> void:
	# Layer: pain grunt + subtle bone crack
	_play_layered("boss_hit", "boss_attack_impact", -4.0, -14.0)

func play_boss_cast() -> void:
	# Layer: alien channeling + low creature hum
	_play_layered("boss_cast", "boss_idle_hum", -4.0, -12.0)

func play_boss_summon() -> void:
	# Triple layer: deep roar + alien + creature breath
	_play_triple_layer("boss_summon", "boss_cast", "boss_idle_hum", -3.0, -8.0, -14.0)

func play_boss_death() -> void:
	# MASSIVE triple layer: death scream + bone crack + roar
	_play_triple_layer("boss_death", "boss_attack_impact", "boss_summon", 0.0, -6.0, -10.0)

func play_boss_buff() -> void:
	# Layer: power-up growl + alien undertone
	_play_layered("boss_buff", "boss_cast", -6.0, -12.0)

func play_boss_stagger() -> void:
	# Layer: grunt + bone crack for heavy impact feel
	_play_layered("boss_stagger", "boss_attack_impact", -2.0, -10.0)

func play_boss_phase() -> void:
	# MASSIVE triple: transformation scream + roar + alien
	_play_triple_layer("boss_phase", "boss_summon", "boss_cast", -2.0, -6.0, -10.0)

func play_boss_taunt() -> void:
	# Layer: evil laugh + subtle creature hum
	_play_layered("boss_taunt", "boss_idle_hum", -6.0, -16.0)

func play_boss_telegraph() -> void:
	# Layer: menacing growl + low alien
	_play_layered("boss_telegraph", "boss_cast", -6.0, -14.0)

# ---------------------------------------------------------------------------
# Ambient / atmosphere
# ---------------------------------------------------------------------------

func play_ambient_hum() -> void:
	# Disabled — was annoying constant tone
	pass

func stop_ambient_hum() -> void:
	_ambient_playing = false
	_ambient_player.stop()

# ---------------------------------------------------------------------------
# Boss phase pitch control
# ---------------------------------------------------------------------------

## Call this when boss HP changes. [param hp_ratio] is 0.0–1.0 (current/max).
## At full HP pitch is normal; at low HP sounds get deeper and more distorted.
func set_boss_hp_pitch(hp_ratio: float) -> void:
	# Full health = 0.0 shift, near death = -0.2 shift (deeper, scarier)
	boss_pitch_shift = lerp(-0.2, 0.0, clampf(hp_ratio, 0.0, 1.0))

## Call on phase transition for a dramatic one-shot pitch drop.
func boss_phase_drop() -> void:
	boss_pitch_shift -= 0.1  # each phase makes it noticeably deeper
