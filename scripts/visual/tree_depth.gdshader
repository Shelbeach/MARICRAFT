shader_type canvas_item;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
	vec4 color=texture(TEXTURE,UV);
	color.rgb=mix(color.rgb,vec3(0.56,0.66,0.55),0.27);
	COLOR=color*tint;
}

