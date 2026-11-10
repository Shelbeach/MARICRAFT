shader_type canvas_item;
render_mode unshaded;
uniform sampler2D stone_a : source_color, repeat_enable, filter_linear;
uniform sampler2D stone_b : source_color, repeat_enable, filter_linear;
uniform vec2 origin_world = vec2(0.0);
uniform vec2 size_world = vec2(256.0,256.0);
uniform float boundary_world_x = 128.0;
uniform float blend_width_world = 48.0;
void fragment(){
 vec2 p=origin_world+UV*size_world;
 float edge=boundary_world_x+8.0*sin(p.y*.067)+4.0*sin(p.y*.137);
 float w=smoothstep(edge-blend_width_world*.5,edge+blend_width_world*.5,p.x);
 COLOR=mix(texture(stone_a,p/512.0),texture(stone_b,p/512.0),w);
}
