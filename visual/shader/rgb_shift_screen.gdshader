shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float rgb_shift_size : hint_range(0.0, 1.0) = 0.02;
uniform vec2 r_shift = vec2(0,0);
uniform vec2 g_shift = vec2(0,0);
uniform vec2 b_shift = vec2(0,0);

void fragment() {
	// screen
	COLOR.r *= texture(SCREEN_TEXTURE, SCREEN_UV/(1.0-rgb_shift_size)-r_shift*rgb_shift_size).r;
	COLOR.g *= texture(SCREEN_TEXTURE, SCREEN_UV/(1.0-rgb_shift_size)-g_shift*rgb_shift_size).g;
	COLOR.b *= texture(SCREEN_TEXTURE, SCREEN_UV/(1.0-rgb_shift_size)-b_shift*rgb_shift_size).b;
}
