shader_type canvas_item;
// Matrix-style falling data/code characters.
// Renders procedural falling columns over the screen.

uniform vec4 rain_color : source_color = vec4(0.1, 0.9, 0.3, 1.0);
uniform float fall_speed : hint_range(0.5, 5.0) = 2.0;
uniform float density : hint_range(4.0, 40.0) = 18.0;
uniform float opacity : hint_range(0.0, 0.5) = 0.12;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float char_pattern(vec2 uv) {
	// Pseudo-random character grid
	vec2 grid = floor(uv);
	vec2 local = fract(uv);

	float h = hash(grid);

	// Simulate character shapes with stepped patterns
	float cx = step(0.15, local.x) * step(local.x, 0.85);
	float cy = step(0.1, local.y) * step(local.y, 0.9);

	// Randomize which "pixels" of the character are lit
	float bit1 = step(0.4, hash(grid + vec2(1.0, 0.0)));
	float bit2 = step(0.5, hash(grid + vec2(0.0, 1.0)));
	float shape = cx * cy * mix(bit1, bit2, step(0.5, local.x));

	return shape * step(0.3, h);
}

void fragment() {
	vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV);

	// Create falling columns
	vec2 rain_uv = SCREEN_UV * vec2(density, density * 1.8);
	float col_hash = hash(vec2(floor(rain_uv.x), 0.0));

	// Each column falls at slightly different speed
	float col_speed = fall_speed * (0.6 + col_hash * 0.8);
	rain_uv.y -= TIME * col_speed;

	// Character pattern
	float ch = char_pattern(rain_uv);

	// Fade based on position in column (head is bright, tail fades)
	float y_frac = fract(rain_uv.y * 0.1 + TIME * col_speed * 0.05);
	float fade = smoothstep(0.0, 0.3, y_frac) * smoothstep(1.0, 0.5, y_frac);

	// Column visibility — not all columns active
	float col_active = step(0.55, col_hash);

	vec3 rain = rain_color.rgb * ch * fade * col_active * opacity;
	COLOR = vec4(screen.rgb + rain, screen.a);
}
