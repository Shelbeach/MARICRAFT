shader_type canvas_item;
uniform sampler2D soil_atlas: filter_linear, repeat_disable;
varying vec2 world_position;
varying vec4 meta;
void vertex(){
	world_position=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy+vec2(0.0,2.5);
	meta=COLOR;
}
vec4 soil(vec2 at,float row){
	vec2 cell=floor(at/32.0);
	float phase=mod(cell.x,4.0)+4.0*mod(cell.y,4.0);
	if(mod(cell.x+3.0*cell.y,7.0)<3.0){phase+=16.0;}
	vec2 source=vec2(2.0+68.0*phase,2.0+68.0*row)+mod(at,32.0)*2.0;
	return texture(soil_atlas,source/vec2(textureSize(soil_atlas,0)));
}
void fragment(){
	vec4 edge=texture(TEXTURE,UV);
	float depth=clamp((world_position.y-510.0)/64.0,0.0,2.0);
	vec3 fill=mix(soil(world_position,4.0+floor(depth)*4.0).rgb,soil(world_position,4.0+ceil(depth)*4.0).rgb,smoothstep(0.0,1.0,fract(depth)));
	float local_y=mod(UV.y*float(textureSize(TEXTURE,0).y)-2.0,68.0)/64.0;
	float surface=meta.r*(1.0-smoothstep(0.28,0.62,local_y));
	float local_x=mod(UV.x*float(textureSize(TEXTURE,0).x)-2.0,68.0)/64.0;
	float flags=round(meta.g*7.0);
	float border=max(mod(flags,2.0)*(1.0-smoothstep(0.0,0.1,local_x)),mod(floor(flags/2.0),2.0)*smoothstep(0.9,1.0,local_x));
	border=max(border,floor(flags/4.0)*smoothstep(0.8,0.98,local_y));
	surface=max(surface,border);
	float ink=1.0-smoothstep(0.06,0.16,max(edge.r,max(edge.g,edge.b)));
	COLOR=vec4(mix(fill,edge.rgb,max(surface,ink)),edge.a);
}
