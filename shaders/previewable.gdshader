shader_type canvas_item;

uniform bool PREVIEW = false;
uniform bool PLACEABLE = true;
uniform bool SELECTED = false;

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
	COLOR = new_color;
}
