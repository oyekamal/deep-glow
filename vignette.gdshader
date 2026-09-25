shader_type canvas_item;
// Smooth dithered vignette: computed per pixel so it never bands like an 8-bit gradient texture.
uniform float strength = 0.62;
uniform vec3 tint = vec3(0.0, 0.01, 0.03);

void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.0, 1.25);
	float d = smoothstep(0.28, 0.78, length(p));
	float n = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	COLOR = vec4(tint, clamp(d * strength + n / 255.0, 0.0, 1.0));
}
