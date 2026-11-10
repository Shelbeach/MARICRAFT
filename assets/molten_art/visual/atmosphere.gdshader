shader_type canvas_item;
render_mode unshaded;
uniform float opacity : hint_range(0.0,1.0)=0.25;
uniform float edge_softness : hint_range(0.0,0.3)=0.12;
void fragment(){
 vec4 c=texture(TEXTURE,UV);
 vec2 edge=min(UV,vec2(1.0)-UV);
 c.a*=smoothstep(0.0,edge_softness,edge.x)*smoothstep(0.0,edge_softness,edge.y)*opacity;
 COLOR=c;
}
