shader_type spatial;

uniform vec4 glow_color : source_color = vec4(0.831, 0.659, 0.286, 1.0);
uniform float pulse_speed : hint_range(0.5, 4.0) = 1.5;
uniform float glow_intensity : hint_range(0.0, 3.0) = 1.5;
uniform float base_brightness : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	EMISSION = glow_color.rgb * (base_brightness + pulse * glow_intensity);
	ALBEDO = glow_color.rgb * 0.1;
	ROUGHNESS = 0.8;
	METALLIC = 0.1;
}
