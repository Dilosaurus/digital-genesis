// Cel/toon shader for 3D characters
// Creates a stylized 2.5D look with discrete light bands
shader_type spatial;
render_mode diffuse_toon, specular_toon;

// Base texture from the model
uniform sampler2D base_texture : source_color, filter_linear_mipmap;
uniform vec4 albedo_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Toon shading parameters
uniform float shade_threshold : hint_range(0.0, 1.0) = 0.5;
uniform float shade_softness : hint_range(0.0, 0.5) = 0.05;
uniform vec4 shade_color : source_color = vec4(0.6, 0.6, 0.7, 1.0);

// Rim lighting
uniform float rim_amount : hint_range(0.0, 1.0) = 0.4;
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.5;
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 tex_color = texture(base_texture, UV) * albedo_tint;
	ALBEDO = tex_color.rgb;
}

void light() {
	float NdotL = dot(NORMAL, LIGHT);

	// Stepped shading
	float light_intensity = smoothstep(shade_threshold - shade_softness,
	                                    shade_threshold + shade_softness,
	                                    NdotL);

	vec3 shaded_color = mix(ALBEDO * shade_color.rgb, ALBEDO, light_intensity);

	// Rim lighting
	float rim_dot = 1.0 - dot(NORMAL, VIEW);
	float rim_intensity = smoothstep(rim_threshold - 0.1, rim_threshold + 0.1, rim_dot);
	rim_intensity *= max(NdotL, 0.0);
	vec3 rim = rim_color.rgb * rim_intensity * rim_amount;

	DIFFUSE_LIGHT += shaded_color * LIGHT_COLOR * ATTENUATION + rim;
}
