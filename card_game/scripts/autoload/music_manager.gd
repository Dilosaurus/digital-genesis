extends Node

## MusicManager — handles background music, ambience, and combat music.
## Supports crossfading between tracks and layered audio.

# Music players (2 for crossfade)
var _music_a: AudioStreamPlayer = null
var _music_b: AudioStreamPlayer = null
var _active_player: AudioStreamPlayer = null  # which one is currently playing

# Ambience player (separate from music)
var _ambience: AudioStreamPlayer = null

# State
var _current_track: String = ""
var _current_ambience: String = ""
var _music_volume: float = 0.8    # 0.0 to 1.0
var _ambience_volume: float = 0.5
var _crossfade_tween: Tween = null
var _is_muted: bool = false

# Track database — maps logical names to file paths.
# These are PLACEHOLDER paths. When actual music files are added,
# update the paths here. The system works without them (silent).
var _tracks: Dictionary = {
	# Menus
	"main_menu": "res://assets/music/main_menu.ogg",
	"character_select": "res://assets/music/character_select.ogg",

	# Combat per act
	"combat_act1": "res://assets/music/combat_act1.ogg",
	"combat_act2": "res://assets/music/combat_act2.ogg",
	"combat_act3": "res://assets/music/combat_act3.ogg",

	# Boss themes
	"boss_gabriel": "res://assets/music/boss_gabriel.ogg",
	"boss_michael": "res://assets/music/boss_michael.ogg",
	"boss_azrael": "res://assets/music/boss_azrael.ogg",
	"boss_metatron": "res://assets/music/boss_metatron.ogg",
	"boss_raphael": "res://assets/music/boss_raphael.ogg",

	# Exploration
	"map_act1": "res://assets/music/map_act1.ogg",
	"map_act2": "res://assets/music/map_act2.ogg",
	"map_act3": "res://assets/music/map_act3.ogg",

	# Events
	"rest_site": "res://assets/music/rest_site.ogg",
	"shop": "res://assets/music/shop.ogg",
	"event": "res://assets/music/event.ogg",

	# Victory / Defeat
	"victory": "res://assets/music/victory.ogg",
	"defeat": "res://assets/music/defeat.ogg",
}

var _ambience_tracks: Dictionary = {
	"dungeon_act1": "res://assets/music/amb_dungeon_act1.ogg",
	"dungeon_act2": "res://assets/music/amb_dungeon_act2.ogg",
	"dungeon_act3": "res://assets/music/amb_dungeon_act3.ogg",
	"combat_tension": "res://assets/music/amb_combat_tension.ogg",
	"boss_room": "res://assets/music/amb_boss_room.ogg",
}

func _ready() -> void:
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	add_child(_music_a)

	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_b)

	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)

	_active_player = _music_a

	# Create audio buses if they don't exist
	_ensure_audio_bus("Music", -6.0)
	_ensure_audio_bus("Ambience", -10.0)


## Play a music track by logical name, with optional crossfade.
func play(track_name: String, crossfade_duration: float = 1.5) -> void:
	if track_name == _current_track:
		return  # Already playing

	var path = _tracks.get(track_name, "")
	if path == "" or not ResourceLoader.exists(path):
		# Track not found — stop current music silently
		if _current_track != "":
			stop(crossfade_duration)
		_current_track = track_name  # Mark as "playing" to avoid re-triggering
		return

	var stream = load(path) as AudioStream
	if not stream:
		return

	_current_track = track_name

	# Crossfade: fade out active, fade in other
	var old_player = _active_player
	var new_player = _music_b if _active_player == _music_a else _music_a

	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()

	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	_crossfade_tween = create_tween().set_parallel(true)
	_crossfade_tween.tween_property(new_player, "volume_db",
		linear_to_db(_music_volume), crossfade_duration)
	if old_player.playing:
		_crossfade_tween.tween_property(old_player, "volume_db",
			-80.0, crossfade_duration)
		_crossfade_tween.chain().tween_callback(old_player.stop)

	_active_player = new_player


## Stop music with optional fade out.
func stop(fade_duration: float = 1.0) -> void:
	_current_track = ""
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()

	if _active_player.playing:
		var tw = create_tween()
		tw.tween_property(_active_player, "volume_db", -80.0, fade_duration)
		tw.tween_callback(_active_player.stop)


## Play ambient sound (separate layer, loops).
func play_ambience(track_name: String, fade_in: float = 2.0) -> void:
	if track_name == _current_ambience:
		return

	var path = _ambience_tracks.get(track_name, "")
	if path == "" or not ResourceLoader.exists(path):
		_current_ambience = track_name
		return

	var stream = load(path) as AudioStream
	if not stream:
		return

	_current_ambience = track_name
	stop_ambience(0.5)

	await get_tree().create_timer(0.5).timeout

	_ambience.stream = stream
	_ambience.volume_db = -80.0
	_ambience.play()

	var tw = create_tween()
	tw.tween_property(_ambience, "volume_db",
		linear_to_db(_ambience_volume), fade_in)


## Stop ambient sound.
func stop_ambience(fade_out: float = 1.0) -> void:
	_current_ambience = ""
	if _ambience.playing:
		var tw = create_tween()
		tw.tween_property(_ambience, "volume_db", -80.0, fade_out)
		tw.tween_callback(_ambience.stop)


## Play the right combat music based on context.
func play_combat_music(enemy_ids: Array, act: int = 1) -> void:
	# Check for boss themes first
	for eid in enemy_ids:
		if _tracks.has("boss_%s" % eid):
			play("boss_%s" % eid)
			return
	# Default combat music per act
	play("combat_act%d" % clampi(act, 1, 3))


## Play map exploration music for the current act.
func play_map_music(act: int = 1) -> void:
	play("map_act%d" % clampi(act, 1, 3))
	play_ambience("dungeon_act%d" % clampi(act, 1, 3))


## Set music volume (0.0 to 1.0).
func set_music_volume(vol: float) -> void:
	_music_volume = clampf(vol, 0.0, 1.0)
	if _active_player.playing:
		_active_player.volume_db = linear_to_db(_music_volume)


## Set ambience volume (0.0 to 1.0).
func set_ambience_volume(vol: float) -> void:
	_ambience_volume = clampf(vol, 0.0, 1.0)
	if _ambience.playing:
		_ambience.volume_db = linear_to_db(_ambience_volume)


## Mute/unmute all music.
func set_muted(muted: bool) -> void:
	_is_muted = muted
	AudioServer.set_bus_mute(_get_bus_index("Music"), muted)
	AudioServer.set_bus_mute(_get_bus_index("Ambience"), muted)


func _ensure_audio_bus(bus_name: String, volume_db: float) -> void:
	if AudioServer.get_bus_index(bus_name) == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_volume_db(idx, volume_db)
		AudioServer.set_bus_send(idx, "Master")


func _get_bus_index(bus_name: String) -> int:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 0  # Master fallback
	return idx
