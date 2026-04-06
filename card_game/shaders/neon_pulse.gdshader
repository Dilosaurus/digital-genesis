shader_type canvas_item;
// Pulsing neon glow overlay — intensifies and fades cyclically.
// Apply to a fullscreen ColorRect.

uniform vec4 glow_color : source_color = vec4(0.6, 0.2, 1.0, 1.0);
uniform float pulse_speed : hint_range(0.1, 5.0) = 1.2;
uniform float min_intensity : hint_range(0.0, 0.5) = 0.02;
uniform float max_intensity : hint_range(0.0, 0.5) = 0.15;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV);

	// Pulsing factor with smooth sine curve
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float intensity = mix(min_intensity, max_intensity, pulse);

	// Apply additive glow — stronger near edges (vignette-aware)
	vec2 center_dist = SCREEN_UV - vec2(0.5);
	float edge_factor = dot(center_dist, center_dist) * 2.0;
	edge_factor = clamp(edge_factor, 0.0, 1.0);

	vec3 glow = glow_color.rgb * intensity * (0.4 + edge_factor * 0.6);
	COLOR = vec4(screen.rgb + glow, screen.a);
}
