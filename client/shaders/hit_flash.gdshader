shader_type spatial;

uniform bool flash_active = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_intensity : hint_range(0.0, 5.0) = 3.0;
uniform sampler2D base_texture : source_color;

void fragment() {
	vec4 base = texture(base_texture, UV);
	if (flash_active) {
		ALBEDO = flash_color.rgb;
		EMISSION = flash_color.rgb * flash_intensity;
	} else {
		ALBEDO = base.rgb;
		EMISSION = vec3(0.0);
	}
	ROUGHNESS = 0.5;
}
