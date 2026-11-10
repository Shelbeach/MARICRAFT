shader_type canvas_item;
render_mode unshaded;
uniform sampler2D variant_b : source_color, repeat_enable, filter_linear;
uniform float tile_world=512.0;
varying vec2 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
 vec2 uv=world_pos/tile_world;
 vec2 cell=floor(uv);
 float choose=step(0.46,fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453));
 vec4 a=texture(TEXTURE,fract(uv));
 vec4 b=texture(variant_b,fract(uv));
 COLOR=mix(a,b,choose);
}
