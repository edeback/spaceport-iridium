shader_type canvas_item;

uniform bool PREVIEW = false;
uniform bool PLACEABLE = true;
uniform bool SELECTED = false;
uniform float PROGRESS : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform sampler2D gradient_texture;

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
	vec2 local_uv = (UV - REGION_RECT.xy) / REGION_RECT.zw;
	vec4 progress_color = texture(gradient_texture, local_uv);
	new_color.a = new_color.a * step(1.0 - PROGRESS, progress_color.r);
	COLOR = new_color;
}
