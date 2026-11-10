shader_type canvas_item;
uniform sampler2D normal_tex : source_color, filter_linear;
uniform sampler2D cast_tex : source_color, filter_linear;
uniform float amount : hint_range(0.0,1.0)=0.0;
varying vec4 vertex_tint;
void vertex(){vertex_tint=COLOR;}
void fragment(){
 vec2 uv_a=UV*vec2(1.0,171.0/154.0);
 vec4 a=texture(normal_tex,uv_a);
 if(uv_a.y>1.0)a=vec4(0.0);
 vec4 b=texture(cast_tex,UV);
 // The crown, hair and eyes always use the SAME source. Only the lower mouth/beard changes.
 float mouth_mask=smoothstep(0.56,0.66,UV.y)*smoothstep(0.40,0.55,UV.x);
 float blend_amount=amount*mouth_mask;
 float alpha=mix(a.a,b.a,blend_amount);
 vec3 premul=mix(a.rgb*a.a,b.rgb*b.a,blend_amount);
 COLOR=vec4(premul/max(alpha,0.0001),alpha)*vertex_tint;
}
