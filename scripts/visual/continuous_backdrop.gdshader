shader_type canvas_item;
uniform vec4 source_uv=vec4(0.0,0.0,1.0,1.0);
uniform float overlap=0.06;
uniform float cycles=1.0;
uniform float phase=0.0;
varying vec4 tint;
void vertex(){ tint=COLOR; }
void fragment(){
	float period=1.0-overlap;
	float x=mod(UV.x*cycles+phase,period);
	vec2 uv=source_uv.xy+vec2(x,UV.y)*source_uv.zw;
	vec4 a=texture(TEXTURE,uv);
	if(x<overlap){
		vec4 b=texture(TEXTURE,source_uv.xy+vec2(x+period,UV.y)*source_uv.zw);
		float w=smoothstep(0.0,overlap,x);
		float alpha=mix(b.a,a.a,w);
		a=vec4(mix(b.rgb*b.a,a.rgb*a.a,w)/max(alpha,0.00001),alpha);
	}
	COLOR=a*tint;
}
