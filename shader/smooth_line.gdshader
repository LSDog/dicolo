shader_type canvas_item;

uniform vec4 color : source_color;
uniform float width = 0.1;
uniform float roundness = 0.5;

uniform vec4 color1 : source_color = vec4(0.0, 0.0, 0.0, 0.0); // transparent
uniform vec4 color2 : source_color = vec4(1.0, 1.0, 1.0, 1.0); // White

void fragment() {
	// get normalized uv coordinates
	vec2 uv = UV / vec2(width, 1.0);
	// calculate distance from center
	float dist = length(uv - vec2(0.5));
	// apply smoothstep interpolation
	float alpha = smoothstep(roundness, 1.0 - roundness, dist);
	// Get the normalized position along the line
	float t = VERTEX.x / (8.0 * 0.5);
	vec4 col = mix(color1, color2, t);
	// Output the color
	COLOR = col;
}