shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float darkness = 0.42;
uniform float blur_radius = 2.5;

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur_radius;
	vec4 color = textureLod(screen_texture, SCREEN_UV, 0.0);
	color += textureLod(screen_texture, SCREEN_UV + vec2(px.x, 0.0), 0.0);
	color += textureLod(screen_texture, SCREEN_UV - vec2(px.x, 0.0), 0.0);
	color += textureLod(screen_texture, SCREEN_UV + vec2(0.0, px.y), 0.0);
	color += textureLod(screen_texture, SCREEN_UV - vec2(0.0, px.y), 0.0);
	color += textureLod(screen_texture, SCREEN_UV + px, 0.0);
	color += textureLod(screen_texture, SCREEN_UV - px, 0.0);
	COLOR = vec4(color.rgb / 7.0 * darkness, 1.0);
}
