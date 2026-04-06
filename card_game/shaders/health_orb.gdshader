shader_type canvas_item;
// Health / Mana orb — liquid fill inside a sphere.
// Adapted from godotshaders.com "Health(Mana) Bar in Ball Container ver 2.1"
// by basar1232. Simplified and adapted for Godot 4.x canvas_item usage.
// Screen-texture refraction removed so the orb works on any background
// without requiring a SubViewport; all colour is self-contained.

// ── Fill ──────────────────────────────────────────────────────────────────────
uniform vec4  water_color      : source_color  = vec4(0.18, 0.55, 1.0, 1.0);
uniform float height           : hint_range(0.0, 1.0, 0.005) = 0.5;
uniform float wave_speed       : hint_range(-10.0, 10.0, 0.05) = 2.0;
uniform float wave_ci          : hint_range(0.0, 0.15, 0.005) = 0.05;
uniform int   wave_num         : hint_range(0, 8) = 2;

// ── Globe rim ─────────────────────────────────────────────────────────────────
uniform vec4  rim_color        : source_color  = vec4(1.0, 1.0, 1.0, 1.0);
uniform float rim_power        : hint_range(1.0, 30.0, 0.5) = 6.0;
uniform float rim_strength     : hint_range(0.0, 1.0, 0.01) = 0.55;

// ── Specular highlight ────────────────────────────────────────────────────────
uniform float specular_strength : hint_range(0.0, 1.0, 0.01) = 0.35;

// ── Dark background inside empty area ─────────────────────────────────────────
uniform vec4  empty_color      : source_color  = vec4(0.04, 0.04, 0.08, 1.0);

void fragment() {
	vec2 uv  = UV;                         // [0,1]²
	vec2 suv = uv - 0.5;                   // centred [-0.5, 0.5]²
	float dist = length(suv);

	// Discard pixels outside the circle.
	if (dist > 0.5) {
		COLOR = vec4(0.0);
		return;
	}

	// ── Wave surface (two sine layers going opposite directions) ────────────────
	float wave_a = sin((cos(suv.x * PI) + TIME * wave_speed) * float(wave_num)) * wave_ci;
	float wave_b = sin((cos(suv.x * PI + PI) + TIME * wave_speed) * float(wave_num)) * wave_ci;

	float surf_a = 1.0 - height + wave_a;  // back wave
	float surf_b = 1.0 - height + wave_b;  // front wave

	vec4 col;

	if (uv.y > surf_b) {
		// Front fill (brighter, slightly lighter colour)
		col = water_color * 1.05;
	} else if (uv.y > surf_a) {
		// Back fill (darker)
		col = water_color * 0.72;
	} else {
		// Empty — dark interior
		col = empty_color;
	}

	// ── Globe rim (Fresnel-style) ───────────────────────────────────────────────
	float rim = pow(dist * 2.0, rim_power);
	col = mix(col, rim_color, rim * rim_strength);

	// ── Specular highlight (top-left crescent) ─────────────────────────────────
	vec2  spec_center = vec2(-0.18, -0.18);
	float spec_dist   = length(suv - spec_center);
	float spec        = smoothstep(0.22, 0.08, spec_dist);
	col.rgb           = mix(col.rgb, vec3(1.0), spec * specular_strength);

	// Preserve circle alpha (already clipped above)
	col.a = 1.0;
	COLOR = col;
}
