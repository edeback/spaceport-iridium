shader_type canvas_item;

uniform bool PREVIEW = false;
uniform bool PLACEABLE = true;
uniform bool SELECTED = false;
uniform float PROGRESS : hint_range(0.0, 1.0, 0.01) = 1.0;
// WI-24: 0 = pristine, 1 = destroyed (= 1 - hp/max). Drives a scorch/crack
// overlay; art can iterate on the look independently of the gameplay wiring.
uniform float DAMAGE : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform sampler2D gradient_texture;

// Cheap value-noise hash for procedural scorch marks (no texture needed).
float damage_hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.13, 289.7))) * 43758.5453);
}

void fragment() { // Called for every pixel the material is visible on.
	vec4 new_color = texture(TEXTURE, UV);
	if (PREVIEW) {
		new_color = new_color * 0.75;
		if (!PLACEABLE) {
			new_color.r = 0.9;
		}
	} else if (SELECTED) {
		new_color.g = 1.0;
	}
	// Scorch overlay scales with DAMAGE: darkens the plating and stamps a few
	// glowing embers where the noise crosses a damage-driven threshold.
	if (DAMAGE > 0.001) {
		float noise = damage_hash(floor(UV * 48.0));
		float scorch = smoothstep(1.0 - DAMAGE, 1.0, noise);
		new_color.rgb = mix(new_color.rgb, new_color.rgb * 0.35, DAMAGE * 0.7);
		new_color.rgb = mix(new_color.rgb, vec3(0.9, 0.35, 0.1), scorch * DAMAGE);
	}
	vec2 local_uv = (UV - REGION_RECT.xy) / REGION_RECT.zw;
	vec4 progress_color = texture(gradient_texture, local_uv);
	new_color.a = new_color.a * max(step(1.0 - PROGRESS, progress_color.r), 0.25);
	COLOR = new_color;
}
