shader_type canvas_item;
// Volumetric light beam / god-ray effect for divine areas.
// Renders soft radial light shafts from a configurable origin.

uniform vec2 light_origin = vec2(0.5, 0.0);
uniform float ray_intensity : hint_range(0.0, 0.5) = 0.15;
uniform float ray_count : hint_range(2.0, 16.0) = 6.0;
uniform float ray_spread : hint_range(0.5, 3.0) = 1.2;
uniform float sway_speed : hint_range(0.0, 2.0) = 0.3;
uniform vec4 ray_color : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

void fragment() {
	vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV);

	vec2 delta = SCREEN_UV - light_origin;
	float dist = length(delta);
	float angle = atan(delta.y, delta.x);

	// Sway the rays gently
	float sway = sin(TIME * sway_speed) * 0.15;
	angle += sway;

	// Generate ray pattern
	float rays = 0.0;
	for (float i = 0.0; i < 8.0; i += 1.0) {
		if (i >= ray_count) break;
		float ray_angle = (i / ray_count) * 3.14159 * 2.0;
		float diff = abs(mod(angle - ray_angle + 3.14159, 6.28318) - 3.14159);
		float ray = smoothstep(ray_spread * 0.15, 0.0, diff);
		// Per-ray flickering
		float flicker = 0.8 + 0.2 * sin(TIME * (1.5 + i * 0.4) + i * 2.0);
		rays += ray * flicker;
	}

	// Distance falloff — stronger near origin, fades with distance
	float falloff = 1.0 - smoothstep(0.0, 1.2, dist);
	falloff *= falloff;

	float final_rays = rays * falloff * ray_intensity;
	vec3 light = ray_color.rgb * final_rays;

	COLOR = vec4(screen.rgb + light, screen.a);
}
