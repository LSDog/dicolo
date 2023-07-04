shader_type canvas_item;
uniform float outline_width = 2.0;
uniform vec4 outline_color: source_color;

void fragment(){
    vec4 col = texture(TEXTURE, UV);
    vec2 ps = TEXTURE_PIXEL_SIZE * outline_width;
    float a;
    float maxa = col.a;
    float mina = col.a;


    for(float x = -1.0; x <= 1.0; x+=0.05) {
        float y = 1.0 - (x*x);
        if(vec2(x,y) == vec2(0.0)) {
            continue; // ignore the center of kernel
        }

        a = texture(TEXTURE, UV + vec2(x,y)*ps).a;
        maxa = max(a, maxa); 
        mina = min(a, mina);
    }

    for(float x = -1.0; x <= 1.0; x+=0.05) {
        float y = -1.0 + (x*x);
        if(vec2(x,y) == vec2(0.0)) {
            continue; // ignore the center of kernel
        }

        a = texture(TEXTURE, UV + vec2(x,y)*ps).a;
        maxa = max(a, maxa); 
        mina = min(a, mina);
    }


    // Fill transparent pixels only, don't overlap texture
    if(col.a < 0.5) {
        COLOR = mix(col, outline_color, maxa-mina);
    } else {
        COLOR = col;
    }
}