shader_type canvas_item;

uniform float dissolve_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 edge_color : source_color = vec4(0.6, 0.3, 1.0, 1.0);
uniform float edge_width : hint_range(0.0, 0.2) = 0.05;
uniform sampler2D noise_tex;  // Optional external noise; uses procedural if unset

// --------------------------------------------------------------------------
// Procedural noise (no external texture required)
// --------------------------------------------------------------------------

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	// Four corners of the cell
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));

	// Smooth interpolation
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float layered_noise(vec2 uv) {
	float n = 0.0;
	float amplitude = 0.5;
	float frequency = 1.0;

	// Three octaves for richer detail
	for (int i = 0; i < 3; i++) {
		n += amplitude * value_noise(uv * frequency * 50.0);
		amplitude *= 0.5;
		frequency *= 2.0;
	}
	return n;
}

// --------------------------------------------------------------------------
// Fragment
// --------------------------------------------------------------------------

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);
	float noise_val = layered_noise(UV);

	// Discard pixels whose noise falls below the dissolve threshold
	if (noise_val < dissolve_amount) {
		discard;
	}

	// Edge glow: blend edge_color near the dissolve boundary
	float edge_start = dissolve_amount;
	float edge_end = dissolve_amount + edge_width;

	if (noise_val < edge_end && dissolve_amount > 0.0) {
		float edge_factor = 1.0 - smoothstep(edge_start, edge_end, noise_val);
		tex_color.rgb = mix(tex_color.rgb, edge_color.rgb, edge_factor * edge_color.a);
		// Boost brightness at the very edge for a glow feel
		tex_color.rgb += edge_color.rgb * edge_factor * 0.4;
	}

	COLOR = tex_color;
}
