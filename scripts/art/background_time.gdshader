shader_type canvas_item;

uniform sampler2D day_texture : source_color, filter_nearest, repeat_disable;
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	COLOR = tint * mix(texture(TEXTURE, UV), texture(day_texture, UV), daylight);
}
