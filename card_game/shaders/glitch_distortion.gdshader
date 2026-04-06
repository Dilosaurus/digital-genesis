shader_type canvas_item;
// Corruption / glitch screen-tear distortion effect.
// Produces intermittent horizontal tears and color channel splitting.

uniform float tear_intensity : hint_range(0.0, 0.1) = 0.02;
uniform float tear_frequency : hint_range(0.5, 10.0) = 3.0;
uniform float chromatic_shift : hint_range(0.0, 0.02) = 0.004;
uniform float block_size : hint_range(2.0, 40.0) = 12.0;
uniform float glitch_chance : hint_range(0.0, 1.0) = 0.15;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;

	// Time-based glitch trigger — intermittent, not constant
	float time_block = floor(TIME * tear_frequency);
	float should_glitch = step(1.0 - glitch_chance, hash(time_block));

	if (should_glitch > 0.5) {
		// Horizontal tear: offset rows of pixels
		float row = floor(uv.y * block_size);
		float row_hash = hash(row + time_block * 7.13);
		float tear_active = step(0.7, row_hash);
		float offset = (row_hash - 0.5) * 2.0 * tear_intensity * tear_active;
		uv.x += offset;
	}

	uv = clamp(uv, vec2(0.0), vec2(1.0));

	// Chromatic aberration — always subtle, stronger during glitch
	float shift = chromatic_shift * (1.0 + should_glitch * 2.0);
	float r = texture(SCREEN_TEXTURE, uv + vec2(shift, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - vec2(shift, 0.0)).b;
	float a = texture(SCREEN_TEXTURE, uv).a;

	// Occasional scanline darkening
	float scanline = 1.0 - 0.04 * step(0.5, fract(uv.y * 300.0)) * should_glitch;

	COLOR = vec4(vec3(r, g, b) * scanline, a);
}
