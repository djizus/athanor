shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform bool flash_active = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_intensity : hint_range(0.0, 5.0) = 3.0;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	if (tex.a < 0.5) {
		discard;
	}
	if (flash_active) {
		ALBEDO = flash_color.rgb * flash_intensity;
	} else {
		ALBEDO = tex.rgb;
	}
	ALPHA = 1.0;
}
