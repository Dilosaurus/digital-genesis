shader_type canvas_item;

uniform float aberration_amount : hint_range(0.0, 20.0) = 0.0;
uniform vec2 aberration_direction = vec2(1.0, 0.0);

void fragment() {
	// Convert pixel offset to UV-space offset using TEXTURE_PIXEL_SIZE
	vec2 offset = normalize(aberration_direction) * aberration_amount * TEXTURE_PIXEL_SIZE;

	float r = texture(TEXTURE, UV + offset).r;
	float g = texture(TEXTURE, UV).g;
	float b = texture(TEXTURE, UV - offset).b;
	float a = texture(TEXTURE, UV).a;

	COLOR = vec4(r, g, b, a);
}
