class_name ArenaConfig
extends Resource
## Defines the visual configuration for a combat arena.
## Each act/floor type maps to one of these configs.

## ---- Layer definition ----
## Each entry: { texture_path: String, motion_type: String, motion_speed: float, parallax_scale: Vector2 }
## motion_type: "static", "scroll", "drift", "float"
@export var act_id: int = 1
@export var arena_name: String = ""
@export var layers: Array[Dictionary] = []

## Particle preset names to spawn (keys into ArenaBackground._PARTICLE_PRESETS)
@export var particle_presets: Array[String] = []

## Shader overlay resource paths (*.gdshader) applied on top of the scene
@export var shader_overlays: Array[String] = []

## Base ambient color tint (applied via CanvasModulate)
@export var ambient_color: Color = Color.WHITE

## Mood variants — mood_name -> { ambient_color, particle_overrides, shader_overrides }
@export var mood_variants: Dictionary = {}

## Optional fog / vignette intensity (0.0 = off, 1.0 = full)
@export var fog_intensity: float = 0.0
@export var vignette_intensity: float = 0.3


# ---------------------------------------------------------------------------
# Factory helpers — returns pre-built configs for the three acts
# ---------------------------------------------------------------------------

static func create_act1_undervault() -> ArenaConfig:
	var cfg: ArenaConfig = ArenaConfig.new()
	cfg.act_id = 1
	cfg.arena_name = "Undervault"
	cfg.layers = [
		{ "texture_path": "", "motion_type": "static",  "motion_speed": 0.0,  "parallax_scale": Vector2(0.05, 0.05) },
		{ "texture_path": "", "motion_type": "drift",   "motion_speed": 3.0,  "parallax_scale": Vector2(0.15, 0.10) },
		{ "texture_path": "", "motion_type": "scroll",  "motion_speed": 8.0,  "parallax_scale": Vector2(0.30, 0.20) },
		{ "texture_path": "", "motion_type": "drift",   "motion_speed": 5.0,  "parallax_scale": Vector2(0.45, 0.30) },
		{ "texture_path": "", "motion_type": "static",  "motion_speed": 0.0,  "parallax_scale": Vector2(0.55, 0.40) },
		{ "texture_path": "", "motion_type": "float",   "motion_speed": 1.5,  "parallax_scale": Vector2(0.65, 0.50) },
		{ "texture_path": "", "motion_type": "drift",   "motion_speed": 6.0,  "parallax_scale": Vector2(0.80, 0.65) },
		{ "texture_path": "", "motion_type": "static",  "motion_speed": 0.0,  "parallax_scale": Vector2(1.00, 0.85) },
	]
	cfg.particle_presets = ["sparks", "dust"]
	cfg.shader_overlays = ["res://shaders/heat_haze.gdshader"]
	cfg.ambient_color = Color(0.85, 0.65, 0.35, 1.0)  # amber under-lighting
	cfg.fog_intensity = 0.25
	cfg.vignette_intensity = 0.45
	cfg.mood_variants = {
		"boss": {
			"ambient_color": Color(0.7, 0.35, 0.2, 1.0),
			"particle_overrides": ["embers", "sparks"],
			"shader_overrides": ["res://shaders/heat_haze.gdshader", "res://shaders/glitch_distortion.gdshader"],
		},
		"elite": {
			"ambient_color": Color(0.75, 0.55, 0.3, 1.0),
			"particle_overrides": ["embers"],
		},
	}
	return cfg


static func create_act2_neon_purgatory() -> ArenaConfig:
	var cfg: ArenaConfig = ArenaConfig.new()
	cfg.act_id = 2
	cfg.arena_name = "Neon Purgatory"
	cfg.layers = [
		{ "texture_path": "", "motion_type": "static",  "motion_speed": 0.0,  "parallax_scale": Vector2(0.05, 0.05) },
		{ "texture_path": "", "motion_type": "scroll",  "motion_speed": 12.0, "parallax_scale": Vector2(0.15, 0.10) },
		{ "texture_path": "", "motion_type": "drift",   "motion_speed": 4.0,  "parallax_scale": Vector2(0.30, 0.20) },
		{ "texture_path": "", "motion_type": "scroll",  "motion_speed": 18.0, "parallax_scale": Vector2(0.40, 0.25) },
		{ "texture_path": "", "motion_type": "float",   "motion_speed": 2.0,  "parallax_scale": Vector2(0.50, 0.35) },
		{ "texture_path": "", "motion_type": "drift",   "motion_speed": 7.0,  "parallax_scale": Vector2(0.65, 0.50) },
		{ "texture_path": "", "motion_type": "scroll",  "motion_speed": 22.0, "parallax_scale": Vector2(0.80, 0.65) },
		{ "texture_path": "", "motion_type": "static",  "motion_speed": 0.0,  "parallax_scale": Vector2(1.00, 0.85) },
	]
	cfg.particle_presets = ["rain", "data_fragments"]
	cfg.shader_overlays = ["res://shaders/neon_pulse.gdshader", "res://shaders/digital_rain.gdshader"]
	cfg.ambient_color = Color(0.7, 0.45, 0.85, 1.0)  # purple-orange neon
	cfg.fog_intensity = 0.15
	cfg.vignette_intensity = 0.35
	cfg.mood_variants = {
		"boss": {
			"ambient_color": Color(0.55, 0.25, 0.75, 1.0),
			"particle_overrides": ["rain", "data_fragments", "sparks"],
			"shader_overrides": ["res://shaders/neon_pulse.gdshader", "res://shaders/glitch_distortion.gdshader"],
		},
		"elite": {
			"ambient_color": Color(0.65, 0.4, 0.9, 1.0),
			"particle_overrides": ["rain", "data_fragments"],
		},
	}
	return cfg


static func create_act3_throne_protocol() -> ArenaConfig:
	var cfg: ArenaConfig = ArenaConfig.new()
	cfg.act_id = 3
	cfg.arena_name = "Throne Protocol"
	cfg.layers = [
		{ "texture_path": "", "motion_type": "static",  "motion_speed": 0.0,  "parallax_scale": Vector2(0.05, 0.05) },
		{ "texture_path": "", "motion_type": "float",   "motion_speed": 1.0,  "parallax_scale": Vector2(0.12, 0.08) },
		{ "texture_path": "", "motion_type": "drift",   "motion_speed": 2.5,  "parallax_scale": Vector2(0.25, 0.18) },
		{ "texture_path": "", "motion_type": "float",   "motion_speed": 1.8,  "parallax_scale": Vector2(0.38, 0.28) },
		{ "texture_path": "", "motion_type": "static",  "motion_speed": 0.0,  "parallax_scale": Vector2(0.50, 0.38) },
		{ "texture_path": "", "motion_type": "drift",   "motion_speed": 3.0,  "parallax_scale": Vector2(0.65, 0.50) },
		{ "texture_path": "", "motion_type": "float",   "motion_speed": 2.2,  "parallax_scale": Vector2(0.80, 0.65) },
		{ "texture_path": "", "motion_type": "static",  "motion_speed": 0.0,  "parallax_scale": Vector2(1.00, 0.85) },
	]
	cfg.particle_presets = ["divine_motes", "dust"]
	cfg.shader_overlays = ["res://shaders/god_rays.gdshader"]
	cfg.ambient_color = Color(1.0, 0.95, 0.8, 1.0)  # white-gold
	cfg.fog_intensity = 0.1
	cfg.vignette_intensity = 0.2
	cfg.mood_variants = {
		"boss": {
			"ambient_color": Color(1.0, 0.85, 0.6, 1.0),
			"particle_overrides": ["divine_motes", "embers"],
			"shader_overrides": ["res://shaders/god_rays.gdshader", "res://shaders/glitch_distortion.gdshader"],
		},
		"elite": {
			"ambient_color": Color(1.0, 0.9, 0.75, 1.0),
			"particle_overrides": ["divine_motes"],
		},
	}
	return cfg


static func get_config_for_act(act: int) -> ArenaConfig:
	match act:
		1: return create_act1_undervault()
		2: return create_act2_neon_purgatory()
		3: return create_act3_throne_protocol()
		_: return create_act1_undervault()
