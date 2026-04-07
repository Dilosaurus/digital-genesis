shader_type canvas_item;
// Glass dome overlay — sits on top of the liquid orb fill, behind the ornate
// frame. Pure additive highlights via standard alpha blending so the liquid
// colour underneath shows through cleanly. No screen-texture sampling.
//
// Effects layered: broad top dome highlight, sharp primary arc reflection,
// secondary smaller arc, pinprick specular dot, rim fresnel glow.

uniform float intensity : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform vec3  highlight_color : source_color = vec3(1.0, 1.0, 1.0);

// Soft top dome highlight (broad, fuzzy bright area).
uniform vec2  dome_center   = vec2(0.05, -0.45);
uniform float dome_radius   : hint_range(0.1, 1.5, 0.01) = 0.7;
uniform float dome_strength : hint_range(0.0, 1.5, 0.01) = 0.6;

// Sharp arc reflections.
uniform float arc_strength  : hint_range(0.0, 1.5, 0.01) = 0.85;

// Pinprick specular dot.
uniform float spec_dot_strength : hint_range(0.0, 1.5, 0.01) = 0.95;

// Rim fresnel glow (brightens the very edge of the sphere).
uniform float rim_strength : hint_range(0.0, 1.5, 0.01) = 0.35;
uniform float rim_power    : hint_range(1.0, 12.0, 0.1) = 5.0;

// ─────────────────────────────────────────────────────────────────────────────
float sd_arc(vec2 p, vec2 sc, float ra, float rb) {
	p.x = abs(p.x);
	return ((sc.y * p.x > sc.x * p.y) ? length(p - sc * ra)
	                                   : abs(length(p) - ra)) - rb;
}

mat2 rot2d(float angle) {
	float c = cos(angle);
	float s = sin(angle);
	return mat2(vec2(c, -s), vec2(s, c));
}

// ─────────────────────────────────────────────────────────────────────────────
void fragment() {
	// Same UV remap as liquid_orb.gdshader so the dome aligns perfectly with
	// the underlying liquid sphere.
	vec2 uv = (UV / -0.48) + vec2(1.038, 1.038);
	float circle_sdf = length(uv);

	// Hard circular mask — must use smoothstep with edge0 < edge1 then invert
	// (smoothstep with edge0 > edge1 is undefined behaviour in GLSL).
	float circle_mask = 1.0 - smoothstep(0.96, 1.0, circle_sdf);
	if (circle_mask <= 0.0) {
		COLOR = vec4(0.0);
		return;
	}

	float r = clamp(circle_sdf, 0.0, 1.0);

	// ── Soft top dome highlight ────────────────────────────────────────────
	float dome_dist = length(uv - dome_center);
	float dome = smoothstep(dome_radius, 0.0, dome_dist) * dome_strength;

	// ── Primary sharp arc reflection ───────────────────────────────────────
	float spec_angle = radians(15.0);
	vec2  spec_sc    = vec2(sin(spec_angle), cos(spec_angle));
	float arc_sdf    = sd_arc(rot2d(radians(60.0)) * uv, spec_sc, 0.62, 0.04);
	float arc        = smoothstep(0.07, 0.0, arc_sdf) * arc_strength;

	// ── Secondary smaller arc highlight ────────────────────────────────────
	float spec_angle2 = radians(2.0);
	vec2  spec_sc2    = vec2(sin(spec_angle2), cos(spec_angle2));
	float arc2_sdf    = sd_arc(rot2d(radians(28.0)) * uv, spec_sc2, 0.78, 0.025);
	float arc2        = smoothstep(0.05, 0.0, arc2_sdf) * arc_strength * 0.7;

	// ── Pinprick specular dot ──────────────────────────────────────────────
	vec2  dot_center = vec2(0.18, -0.55);
	float dot_dist   = length(uv - dot_center);
	float spec_dot   = smoothstep(0.12, 0.0, dot_dist) * spec_dot_strength;
	spec_dot += smoothstep(0.05, 0.0, dot_dist) * spec_dot_strength * 0.6;

	// ── Rim fresnel glow ───────────────────────────────────────────────────
	float rim = pow(clamp(r + 0.02, 0.0, 1.0), rim_power) * rim_strength;

	// ── Composite as a single alpha-blended highlight pass ─────────────────
	// Standard alpha blend: result = dst*(1-a) + src*a
	// With src = highlight_color and a = highlight_sum, the underlying liquid
	// gets lerped toward the highlight colour by the highlight strength.
	float highlight_sum = clamp((dome + arc + arc2 + spec_dot + rim) * intensity,
	                            0.0, 1.0);

	COLOR = vec4(highlight_color, highlight_sum * circle_mask);
}
