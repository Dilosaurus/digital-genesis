shader_type canvas_item;
// Card border glow — renders an outer glow halo around the card's opaque pixels.
// Designed to be lightweight: single-pass SDF-style edge detection on the alpha channel.
// Apply this to the GlowBorder Panel node (or a same-size ColorRect placed behind the card).

// Glow color and brightness
uniform vec4 glow_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.2;

// How wide the glow spreads beyond the card edge (in UV units)
uniform float glow_radius : hint_range(0.005, 0.08) = 0.025;

// Pulse animation — set pulse_speed to 0.0 to disable
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.8;
uniform float pulse_min : hint_range(0.0, 1.0) = 0.6;
uniform float pulse_max : hint_range(0.0, 1.0) = 1.0;

// Inner vignette darkens the card center slightly for depth
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.18;

// Card corner radius as fraction of card width (must match StyleBoxFlat corner radius)
uniform float corner_radius : hint_range(0.0, 0.2) = 0.045;

// The card's own texture (sampled from the node this shader is on)
uniform sampler2D TEXTURE;

// Signed distance to a rounded rectangle.
// p = position relative to center, b = half-extents, r = corner radius
float sdf_rounded_rect(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + vec2(r);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 uv = UV;

	// Card half-extents in UV space (card fills UV [0,1])
	vec2 half_size = vec2(0.5);
	// Map UV to signed [-0.5, 0.5] space centered on the card
	vec2 p = uv - vec2(0.5);

	float r = corner_radius;
	float dist = sdf_rounded_rect(p, half_size, r);

	// --- Outer glow ---
	// Positive dist = outside the card shape
	float glow_alpha = 0.0;
	if (dist > 0.0) {
		// Exponential falloff from the edge
		glow_alpha = exp(-dist / glow_radius) * glow_intensity;
		glow_alpha = clamp(glow_alpha, 0.0, 1.0);
	}

	// --- Pulse modulation ---
	float pulse = 1.0;
	if (pulse_speed > 0.0) {
		pulse = mix(pulse_min, pulse_max, sin(TIME * pulse_speed) * 0.5 + 0.5);
	}
	glow_alpha *= pulse;

	// --- Inner vignette (only inside the card) ---
	float vignette = 0.0;
	if (dist <= 0.0) {
		// How far inside: 0 at edge, grows toward center
		float inside = -dist;
		// Compute distance from card center in UV space
		float center_dist = length(p) * 2.0; // 0 at center, ~1 at corner
		vignette = vignette_strength * (1.0 - center_dist);
		vignette = max(vignette, 0.0);
	}

	// --- Compose final color ---
	// Outside card: additive glow color, fully transparent background
	// Inside card: dark vignette overlay, semi-transparent
	vec4 existing = texture(TEXTURE, uv);

	if (dist > 0.0) {
		// Pure glow halo outside the card bounds
		COLOR = vec4(glow_color.rgb, glow_alpha * glow_color.a);
	} else {
		// Vignette darkening inside card area — multiply blended
		float darkness = vignette;
		COLOR = vec4(0.0, 0.0, 0.0, darkness * existing.a);
	}
}
