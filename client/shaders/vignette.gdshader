shader_type canvas_item;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    float dist = distance(UV, vec2(0.5));
    float vignette = smoothstep(vignette_softness, vignette_softness - 0.3, dist);
    COLOR = vec4(0.0, 0.0, 0.0, (1.0 - vignette) * vignette_intensity);
}
