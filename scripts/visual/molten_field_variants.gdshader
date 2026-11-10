shader_type canvas_item;
render_mode unshaded;
uniform sampler2D stone_a : source_color, repeat_enable, filter_linear;
uniform sampler2D stone_a_variant : source_color, repeat_enable, filter_linear;
uniform sampler2D stone_b : source_color, repeat_enable, filter_linear;
uniform sampler2D stone_b_variant : source_color, repeat_enable, filter_linear;
uniform vec2 origin_world;
uniform vec2 size_world;
uniform bool transition_enabled=false;
uniform float boundary_world_x=2250.0;
void fragment() {
 vec2 p=origin_world+UV*size_world;
 vec2 uv=p/512.0;
 vec2 cell=floor(uv);
 float choice=step(0.46,fract(sin(dot(cell,vec2(127.1,311.7)))*43758.5453));
 // B's 64px border matches A. Never mirror either asymmetrical field.
 vec4 a=mix(texture(stone_a,uv),texture(stone_a_variant,uv),choice);
 vec4 b=mix(texture(stone_b,uv),texture(stone_b_variant,uv),choice);
 float edge=boundary_world_x+8.0*sin(p.y*.067)+4.0*sin(p.y*.137);
 float blend=transition_enabled?smoothstep(edge-24.0,edge+24.0,p.x):0.0;
 COLOR=mix(a,b,blend);
}
