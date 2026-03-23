shader_type spatial;
render_mode specular_disabled, rim_disabled;

uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D texture_albedo : source_color, hint_default_white;

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = (albedo_tex * albedo_color).rgb;
	
	// Apply flash effect
	ALBEDO = mix(ALBEDO, vec3(1.0), flash_amount);
}

void light() {
	float NdotL = max(0.0, dot(NORMAL, LIGHT));
	float shadow_band = 1.0;
	
	// Cel shading shadow bands
	if (NdotL < 0.1) {
		shadow_band = 0.3;  // Dark shadow
	} else if (NdotL < 0.5) {
		shadow_band = 0.7;  // Mid shadow
	} else {
		shadow_band = 1.0;  // Bright
	}
	
	DIFFUSE_LIGHT += LIGHT_COLOR * shadow_band;
}
