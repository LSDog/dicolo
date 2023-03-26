shader_type canvas_item;

uniform float rotation=0;

void fragment() {
	vec2 uv = UV;
	vec2 rel = uv-vec2(0.5,0.5);
	float angle = length(rel)*rotation;
	mat2 rot = mat2(vec2(cos(angle),-sin(angle)),vec2(sin(angle),cos(angle)));
	rel = rot * rel;
	uv = clamp(rel + vec2(0.5,0.5),vec2(0,0),vec2(1,1));
	COLOR.rgb = texture(TEXTURE,uv).rgb;
}