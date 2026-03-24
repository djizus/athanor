shader_type spatial;

uniform vec4 stone_color : source_color = vec4(0.15, 0.13, 0.12, 1.0);
uniform vec4 crack_color : source_color = vec4(0.05, 0.04, 0.04, 1.0);
uniform vec4 emission_color : source_color = vec4(0.83, 0.66, 0.29, 1.0);
uniform float emission_strength : hint_range(0.0, 2.0) = 0.3;
uniform float tile_scale : hint_range(1.0, 20.0) = 6.0;
uniform float crack_threshold : hint_range(0.0, 1.0) = 0.42;
uniform float edge_darken_radius : hint_range(0.0, 1.0) = 0.7;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x),
	           mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	v += vnoise(p) * 0.5;
	v += vnoise(p * 2.0) * 0.25;
	v += vnoise(p * 4.0) * 0.125;
	return v;
}

void fragment() {
	vec2 uv = UV * tile_scale;
	float n = fbm(uv);
	float cracks = step(crack_threshold, fbm(uv * 1.5 + 3.7));

	vec3 base = mix(stone_color.rgb, stone_color.rgb * 1.5, n);
	base = mix(base, crack_color.rgb, cracks * 0.5);

	vec2 grid_uv = fract(uv);
	float grid_line = step(0.96, grid_uv.x) + step(0.96, grid_uv.y);
	grid_line = clamp(grid_line, 0.0, 1.0);
	base = mix(base, base * 0.7, grid_line * 0.3);

	float dist = length(UV - vec2(0.5)) * 2.0;
	float vignette = 1.0 - smoothstep(edge_darken_radius, 1.0, dist) * 0.6;
	base *= vignette;

	ALBEDO = base * 1.3;
	ROUGHNESS = 0.85;
	METALLIC = 0.02;

	EMISSION = emission_color.rgb * emission_strength * (1.0 - cracks) * 0.4
	         * smoothstep(0.3, 0.5, n);
}
