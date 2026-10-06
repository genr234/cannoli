shader_type canvas_item;
render_mode unshaded;
// Full-screen post effects: punch zoom, lens distortion, chromatic aberration and vignette.
// Every uniform is neutral at its default, so the layer can stay idle at no visual cost.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

// Zoom towards the screen center. 0.1 shows 10 percent less of the picture.
uniform float zoom = 0.0;
// Barrel distortion when positive, pincushion when negative.
uniform float lens_distortion = 0.0;
// How far the red and blue channels slide apart, as a share of the screen.
uniform float chromatic_aberration = 0.0;
// 0 is no vignette, 1 darkens the corners fully.
uniform float vignette_intensity = 0.0;
// Radius where the darkening starts, 0 is the center and 1 the far corner.
uniform float vignette_start = 0.35;
// How soft the transition is.
uniform float vignette_softness = 0.6;
uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

vec3 sample_split(vec2 centered, float spread) {
	vec2 offset = centered * spread;
	float r = texture(screen_texture, centered + 0.5 + offset).r;
	float g = texture(screen_texture, centered + 0.5).g;
	float b = texture(screen_texture, centered + 0.5 - offset).b;
	return vec3(r, g, b);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 centered = SCREEN_UV - 0.5;
	vec2 shown = centered / (1.0 + zoom);
	vec2 scaled = shown * vec2(aspect, 1.0);
	float r2 = dot(scaled, scaled);
	shown *= 1.0 + lens_distortion * r2 * 2.0;
	vec3 color = sample_split(shown, chromatic_aberration * 4.0);
	vec2 edge = centered * vec2(aspect, 1.0);
	float far_corner = length(vec2(aspect, 1.0)) * 0.5;
	float radius = length(edge) / far_corner;
	float amount = smoothstep(vignette_start, vignette_start + max(vignette_softness, 0.001), radius);
	color = mix(color, vignette_color.rgb, amount * clamp(vignette_intensity, 0.0, 1.0) * vignette_color.a);
	COLOR = vec4(color, 1.0);
}
