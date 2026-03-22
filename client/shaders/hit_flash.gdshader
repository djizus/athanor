shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

uniform bool flash_active = false;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_intensity : hint_range(0.0, 5.0) = 3.0;
uniform sampler2D base_texture : source_color, filter_linear_mipmap;

void fragment() {
	vec4 tex = texture(base_texture, UV);
	ALPHA = tex.a;
	if (flash_active) {
		ALBEDO = flash_color.rgb * flash_intensity;
	} else {
		ALBEDO = tex.rgb;
	}
}
