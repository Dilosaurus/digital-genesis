shader_type canvas_item;
// Scanline overlay + radial vignette for CRT/atmospheric UI feel.
// Apply to a fullscreen ColorRect placed above background layers.

uniform float scanline_opacity : hint_range(0.0, 0.4) = 0.10;
uniform float scanline_density : hint_range(50.0, 400.0) = 180.0;
uniform float vignette_strength : hint_range(0.0, 2.0) = 1.1;
uniform float vignette_softness : hint_range(0.1, 1.5) = 0.6;
uniform float scroll_offset : hint_range(0.0, 4.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec4 screen = texture(SCREEN_TEXTURE, SCREEN_UV);

	// Scrolling scanlines
	float line = fract((SCREEN_UV.y + scroll_offset / scanline_density) * scanline_density);
	float scan = smoothstep(0.0, 0.35, line) * smoothstep(1.0, 0.65, line);
	float scan_dark = 1.0 - scan * scanline_opacity;

	// Radial vignette — darkens edges, leaves center bright
	vec2 center = SCREEN_UV - vec2(0.5);
	float dist = dot(center, center);
	float vignette = 1.0 - smoothstep(vignette_softness * 0.5, vignette_softness, dist * vignette_strength);

	vec3 col = screen.rgb * scan_dark * vignette;
	COLOR = vec4(col, screen.a);
}
