shader_type canvas_item;

uniform float health_ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 bar_color : source_color = vec4(0.75, 0.35, 0.15, 1.0);
uniform vec4 bg_color : source_color = vec4(0.12, 0.08, 0.06, 0.9);
uniform vec4 border_color : source_color = vec4(0.21, 0.165, 0.07, 1.0);
uniform float border : hint_range(0.0, 0.15) = 0.06;

void fragment() {
	float bx = border;
	float by = border * 4.0;
	bool on_border = UV.x < bx || UV.x > 1.0 - bx || UV.y < by || UV.y > 1.0 - by;
	if (on_border) {
		COLOR = border_color;
	} else {
		float fill_x = (UV.x - bx) / (1.0 - 2.0 * bx);
		if (fill_x <= health_ratio) {
			vec3 col = bar_color.rgb;
			if (health_ratio < 0.3) {
				col = vec3(0.85, 0.15, 0.15);
			} else if (health_ratio < 0.6) {
				float t = (health_ratio - 0.3) / 0.3;
				col = mix(vec3(0.85, 0.15, 0.15), bar_color.rgb, t);
			}
			COLOR = vec4(col, 1.0);
		} else {
			COLOR = bg_color;
		}
	}
}
