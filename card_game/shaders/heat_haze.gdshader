shader_type canvas_item;
// Subtle heat distortion / energy haze effect.
// Apply to a fullscreen ColorRect overlay.

uniform float intensity : hint_range(0.0, 0.05) = 0.008;
uniform float speed : hint_range(0.0, 5.0) = 1.5;
uniform float scale : hint_range(1.0, 50.0) = 12.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Two offset sine waves for organic distortion
	float offset_x = sin(uv.y * scale + TIME * speed) * intensity;
	float offset_y = cos(uv.x * scale * 0.7 + TIME * speed * 0.8) * intensity * 0.5;

	vec2 distorted_uv = uv + vec2(offset_x, offset_y);
	distorted_uv = clamp(distorted_uv, vec2(0.0), vec2(1.0));

	vec4 col = texture(SCREEN_TEXTURE, distorted_uv);
	COLOR = col;
}
