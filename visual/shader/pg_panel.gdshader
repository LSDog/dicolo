shader_type canvas_item;

uniform float rgb_shift_size : hint_range(0.0, 1.0) = 0.02;
uniform vec2 r_shift = vec2(0,0);
uniform vec2 g_shift = vec2(0,0);
uniform vec2 b_shift = vec2(0,0);

vec4 move_rect(vec4 rect, vec2 move) {
	rect[0] += move.x;
	rect[1] += move.y;
	rect[2] += move.x;
	rect[3] += move.y;
	return rect;
}

bool inBox(vec2 uv, vec4 rect) {
	
	return rect[0] < uv.x && uv.x < rect[2] && rect[1] < uv.y && uv.y < rect[3];
}

void fragment() {
	
	// rgb offset
	// rect out
	vec4 rect = vec4(0.0, 0.0, 1.0-rgb_shift_size, 1.0-rgb_shift_size);
	float r = 0.0;
	float g = 0.0;
	float b = 0.0;
	if (inBox(UV, move_rect(rect, r_shift*rgb_shift_size))) r = 1.0;
	if (inBox(UV, move_rect(rect, g_shift*rgb_shift_size))) g = 1.0;
	if (inBox(UV, move_rect(rect, b_shift*rgb_shift_size))) b = 1.0;
	COLOR.rgb *= vec3(r,g,b);
}