shader_type canvas_item;

// ── HP Bar Fill Shader ────────────────────────────────────────────────────────
// Features:
//   - Top-to-bottom gradient (lighter top, darker bottom)
//   - Animated horizontal shimmer sweep
//   - Low-HP warning pulse (below 25%)
//   - All driven by uniforms so GDScript can control them

// ── Fill gradient colours ─────────────────────────────────────────────────────
uniform vec4 color_top    : source_color = vec4(0.28, 1.00, 0.45, 1.0);
uniform vec4 color_bottom : source_color = vec4(0.08, 0.55, 0.18, 1.0);

// ── Shimmer ───────────────────────────────────────────────────────────────────
uniform float shimmer_speed     : hint_range(0.0, 4.0, 0.05) = 0.9;
uniform float shimmer_width     : hint_range(0.0, 0.5, 0.01) = 0.12;
uniform float shimmer_intensity : hint_range(0.0, 1.0, 0.01) = 0.30;

// ── Low-HP pulse ──────────────────────────────────────────────────────────────
// Set to 1.0 from GDScript when HP < 25% to enable the pulse.
uniform float low_hp : hint_range(0.0, 1.0, 1.0) = 0.0;
uniform float pulse_speed     : hint_range(0.0, 8.0, 0.1) = 3.0;
uniform float pulse_intensity : hint_range(0.0, 1.0, 0.01) = 0.35;

// ── Damage flash ──────────────────────────────────────────────────────────────
// GDScript tweens this from 1.0 → 0.0 on damage; blends in a white/red flash.
uniform float flash_amount : hint_range(0.0, 1.0, 0.01) = 0.0;

void fragment() {
	// 1. Vertical gradient
	vec4 col = mix(color_top, color_bottom, UV.y);

	// 2. Shimmer — diagonal bright band moving left-to-right
	float shimmer_pos = fract(TIME * shimmer_speed * 0.25);
	float dist_from_band = abs(UV.x - shimmer_pos);
	float shimmer = smoothstep(shimmer_width, 0.0, dist_from_band) * shimmer_intensity;
	col.rgb = mix(col.rgb, vec3(1.0), shimmer);

	// 3. Low-HP pulse — multiply brightness by a sine wave
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;   // 0..1
	float pulse_boost = 1.0 + pulse * pulse_intensity * low_hp;
	col.rgb *= pulse_boost;

	// 4. Damage flash — blend towards bright red-white
	vec3 flash_color = mix(vec3(1.0, 0.4, 0.3), vec3(1.0), 0.4);
	col.rgb = mix(col.rgb, flash_color, flash_amount);

	COLOR = col;
}
