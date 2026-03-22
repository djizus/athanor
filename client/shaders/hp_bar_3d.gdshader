shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 bar_color : source_color = vec4(0.75, 0.35, 0.15, 1.0);
uniform vec4 bg_color : source_color = vec4(0.12, 0.08, 0.06, 0.9);
uniform vec4 border_color : source_color = vec4(0.21, 0.165, 0.07, 1.0);
uniform float border : hint_range(0.0, 0.15) = 0.06;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]
	);
}

void fragment() {
	float bx = border;
	float by = border * 4.0;
	bool on_border = UV.x < bx || UV.x > 1.0 - bx || UV.y < by || UV.y > 1.0 - by;
	if (on_border) {
		ALBEDO = border_color.rgb;
		ALPHA = 1.0;
		return;
	}
	float fill_x = (UV.x - bx) / (1.0 - 2.0 * bx);
	if (fill_x <= health_ratio) {
		vec3 col = bar_color.rgb;
		if (health_ratio < 0.3) {
			col = vec3(0.85, 0.15, 0.15);
		} else if (health_ratio < 0.6) {
			float t = (health_ratio - 0.3) / 0.3;
			col = mix(vec3(0.85, 0.15, 0.15), bar_color.rgb, t);
		}
		ALBEDO = col;
	} else {
		ALBEDO = bg_color.rgb;
	}
	ALPHA = 1.0;
}
