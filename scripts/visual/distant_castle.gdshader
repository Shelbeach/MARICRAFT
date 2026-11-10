shader_type canvas_item;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
	// Premultiplied taps avoid dark fringes around the transparent silhouette.
	vec4 sum=vec4(0.0);
	for(int x=-1;x<=1;x++){
		for(int y=-1;y<=1;y++){
			vec4 sample_color=texture(TEXTURE,UV+vec2(float(x),float(y))*TEXTURE_PIXEL_SIZE*1.8);
			float weight=(x==0?2.0:1.0)*(y==0?2.0:1.0);
			sum+=vec4(sample_color.rgb*sample_color.a,sample_color.a)*weight;
		}
	}
	vec3 blurred=sum.rgb/max(sum.a,0.001);
	vec3 haze=mix(blurred,vec3(0.56,0.69,0.75),0.58);
	COLOR=vec4(haze*tint.rgb,sum.a/16.0*0.9*tint.a);
}
