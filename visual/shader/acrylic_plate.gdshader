shader_type canvas_item;

uniform bool rim_light = false;
uniform float rim_thickness : hint_range(0, 40) = 5.0;
uniform float rim_intense : hint_range(0, 1) = 1.0;
uniform bool rim_extra_thick = false;
uniform vec2 rim_light_pos = vec2(0.25, 0.5);

uniform bool diffuse_reflection = false;
uniform float diffuse_intense : hint_range(0, 1) = 1.0;
uniform vec2 diffuse_light_pos = vec2(0.0, 0.0);

void fragment() {
	
	float light_add = 0.0;
	
	if (rim_light) {
		vec2 size = TEXTURE_PIXEL_SIZE * rim_thickness;
		float outline = texture(TEXTURE, UV + vec2(-size.x, 0)).a;
		outline *= texture(TEXTURE, UV + vec2(0, size.y)).a;
		outline *= texture(TEXTURE, UV + vec2(size.x, 0)).a;
		outline *= texture(TEXTURE, UV + vec2(0, -size.y)).a;
		if (rim_extra_thick) {
			outline *= texture(TEXTURE, UV + vec2(-size.x, size.y)).a;
			outline *= texture(TEXTURE, UV + vec2(size.x, size.y)).a;
			outline *= texture(TEXTURE, UV + vec2(-size.x, -size.y)).a;
			outline *= texture(TEXTURE, UV + vec2(size.x, -size.y)).a;
		}
		outline = 1.0 - outline;
		
		if (rim_light) outline *= 1.0-length(rim_light_pos-UV);
		
		vec4 color = texture(TEXTURE, UV);
		float rim_cap = outline * color.a * rim_intense;
		light_add += rim_cap;
	}
	
	if (diffuse_reflection) {
		light_add += light_add == 0.0 ? (1.0-length(diffuse_light_pos-UV))*diffuse_intense : 0.0;
	}
	
	COLOR.rgb += light_add;
}