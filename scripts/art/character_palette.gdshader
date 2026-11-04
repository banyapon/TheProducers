shader_type canvas_item;
uniform vec4 source_colors[15];
uniform vec4 target_colors[15];
uniform int color_count = 0;
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	for (int i = 0; i < color_count; i++) {
		if (distance(pixel.rgb, source_colors[i].rgb) < 0.003) {
			pixel.rgb = target_colors[i].rgb;
			break;
		}
	}
	COLOR = vertex_tint * pixel;
}
