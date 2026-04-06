shader_type canvas_item;
// Liquid-fill orb — cleaner visual with dual-layer waves, ring, Fresnel glass,
// and arc specular highlights. Adapted from godotshaders.com
// "2D Liquid Fill Inside Sphere v2". Godot 4.x compatible; self-contained,
// no screen-texture dependency.

// ── Colour ────────────────────────────────────────────────────────────────────
uniform vec3 back_fill_colour        : source_color = vec3(0.35, 0.85, 1.00);
uniform vec3 front_fill_inner_colour : source_color = vec3(0.20, 0.70, 1.00);
uniform vec3 front_fill_outer_colour : source_color = vec3(0.00, 0.28, 0.90);
uniform vec3 ring_colour             : source_color = vec3(0.05, 0.10, 0.20);
uniform vec3 fresnel_colour          : source_color = vec3(0.40, 0.80, 1.00);
uniform vec3 inner_ring_glow_colour  : source_color = vec3(0.10, 0.80, 1.00);

// ── Layout ────────────────────────────────────────────────────────────────────
uniform float ring_width                 : hint_range(0.01, 0.4,  0.005) = 0.12;
uniform float inner_circle_radius_offset : hint_range(0.0,  0.2,  0.005) = 0.0;

// ── Fill ──────────────────────────────────────────────────────────────────────
// fill_value range [−1, 1] maps to empty→full; 0 = half full.
// The script drives this uniform via fill_ratio property.
uniform float fill_value : hint_range(-1.0, 1.0, 0.005) = 0.0;

// ─────────────────────────────────────────────────────────────────────────────
// SDF helpers
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
	// Remap UV so the sphere is centred with radius ≈ 1 in "orb space".
	vec2 uv = (UV / -0.48) + vec2(1.038, 1.038);

	float circle_sdf = length(uv);

	float one_minus_ring = 1.0 - ring_width;
	float circle_a       = step(circle_sdf, 1.0);
	float circle_b       = step(circle_sdf, one_minus_ring);
	float ring           = circle_a - circle_b;

	float fill_mask_circle = step(circle_sdf,
		one_minus_ring - inner_circle_radius_offset);

	// ── Inner ring glow ────────────────────────────────────────────────────────
	float ring_glow_sdf = circle_sdf - 1.0;
	const float INNER_OFFSET = 0.15;
	const float INNER_WIDTH  = 0.01;
	const float INNER_POWER  = 1.2;

	float inner_ring_glow = ring_glow_sdf + INNER_OFFSET;
	inner_ring_glow = pow(INNER_WIDTH / inner_ring_glow, INNER_POWER);
	inner_ring_glow = clamp(inner_ring_glow - fill_mask_circle, 0.0, 1.0);

	// ── Animated liquid fill ───────────────────────────────────────────────────
	const float FILL_ANIM_FREQ = 4.0;
	const float FILL_ANIM_AMP  = 0.05;
	const float WAVE_FREQ      = 2.0;
	const float WAVE_AMP       = 0.05;
	const float WAVE_ANIM      = 2.0;

	float fill_anim = sin(TIME * FILL_ANIM_FREQ) * FILL_ANIM_AMP;

	float front_phase = (TIME * WAVE_ANIM + uv.x) * WAVE_FREQ;
	float back_phase  = (TIME * -WAVE_ANIM + uv.x) * WAVE_FREQ;

	float vertical_band = smoothstep(0.1, 0.9,
		sin(uv.x + (PI * 0.5)) - 0.3);

	const float ANIMATED_BAND_STRENGTH = 0.125;
	float anim_band = vertical_band * ANIMATED_BAND_STRENGTH
	                  * sin(TIME * FILL_ANIM_FREQ);

	float front_waves = sin(front_phase) * WAVE_AMP + anim_band;
	float back_waves  = sin(back_phase + PI) * WAVE_AMP - anim_band;

	fill_anim *= vertical_band;

	float fill_progress = fill_value;
	// Subtle breathing animation on the fill level itself.
	fill_progress += sin(TIME * PI) * 0.04;

	float front_fill = step(uv.y, (fill_anim + front_waves) + fill_progress);
	float back_fill  = step(uv.y, (-fill_anim + back_waves) + fill_progress);

	front_fill *= fill_mask_circle;
	back_fill  *= fill_mask_circle;
	back_fill   = clamp(back_fill - front_fill, 0.0, 1.0);

	float fill_mask_empty = 1.0 - (front_fill + back_fill);
	fill_mask_empty *= fill_mask_circle;

	// ── Fresnel glass on empty region ──────────────────────────────────────────
	const float FRESNEL_OFFSET = 0.01;
	const float FRESNEL_POWER  = 5.0;
	float fresnel = pow(clamp((circle_sdf + FRESNEL_OFFSET) * fill_mask_empty, 0.0, 1.0),
	                    FRESNEL_POWER);

	// ── Front-fill Fresnel gradient ────────────────────────────────────────────
	const float FF_FRESNEL_POWER  = 5.0;
	const float FF_FRESNEL_OFFSET = 0.02;
	float ff_fresnel = pow(clamp(
		(circle_sdf + FF_FRESNEL_OFFSET) * (1.0 - fill_mask_empty),
		0.0, 1.0), FF_FRESNEL_POWER);

	// ── Specular arc highlights ────────────────────────────────────────────────
	float spec_angle1 = radians(15.0);
	float spec_angle2 = radians(2.0);
	float spec_rot1   = radians(60.0);
	float spec_rot2   = radians(28.0);

	vec2 spec_sc1 = vec2(sin(spec_angle1), cos(spec_angle1));
	vec2 spec_sc2 = vec2(sin(spec_angle2), cos(spec_angle2));

	const float SPEC_OFFSET = 0.35;
	const float SPEC_WIDTH  = 0.07;

	float spec1 = step(sd_arc(rot2d(spec_rot1) * uv, spec_sc1,
	              1.0 - SPEC_OFFSET, SPEC_WIDTH), 0.0);
	float spec2 = step(sd_arc(rot2d(spec_rot2) * uv, spec_sc2,
	              1.0 - SPEC_OFFSET, SPEC_WIDTH), 0.0);

	const float SPECULAR_STRENGTH = 0.2;
	float specular = (spec1 + spec2) * SPECULAR_STRENGTH;

	// ── Composite ─────────────────────────────────────────────────────────────
	vec3 front_fill_colour = mix(front_fill_inner_colour, front_fill_outer_colour, ff_fresnel);

	const vec3 SPECULAR_COLOUR      = vec3(1.0, 1.0, 0.9);
	const vec3 OUTER_RING_GLOW_COL  = vec3(1.0, 0.8, 0.1);

	vec3 rgb =
		ring            * ring_colour           +
		inner_ring_glow * inner_ring_glow_colour +
		front_fill      * front_fill_colour      +
		back_fill       * back_fill_colour       +
		fresnel         * fresnel_colour         +
		specular        * SPECULAR_COLOUR;

	// Dark background behind the liquid
	const float BG_POWER    = 0.6;
	const float BG_STRENGTH = 0.65;
	vec2 nc_uv = (uv - 0.5) * 2.0;
	float bg_grad = pow(clamp(length(nc_uv), 0.0, 1.0), BG_POWER);
	vec3 bg = mix(vec3(0.10, 0.0, 0.25), vec3(0.0), bg_grad)
	          * clamp(1.0 - (front_fill + back_fill + ring), 0.0, 1.0)
	          * BG_STRENGTH;
	rgb += bg;

	float mask = ring + front_fill + back_fill + fresnel + clamp(specular, 0.0, 1.0);
	mask = clamp(mask + inner_ring_glow, 0.0, 1.0);

	COLOR = vec4(rgb, mask);
}
