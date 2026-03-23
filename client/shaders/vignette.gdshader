shader_type canvas_item;

uniform float strength : hint_range(0.0, 2.0) = 0.8;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
	vec2 uv = UV - center;
	float dist = length(uv) * 1.4;
	float vignette = 1.0 - pow(dist, 2.0) * strength;
	COLOR.a = 1.0 - clamp(vignette, 0.0, 1.0);
	COLOR.rgb = vec3(0.0);
}
