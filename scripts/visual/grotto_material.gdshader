shader_type canvas_item;
uniform sampler2D stone: filter_linear, repeat_disable;
varying vec2 world_position;
varying vec4 tint;
void vertex() {
	tint=COLOR;
	world_position=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;
}
vec3 field_at(vec2 uv) {
	vec2 p=fract(uv);
	vec2 w=smoothstep(vec2(0.0),vec2(0.16),p)*(1.0-smoothstep(vec2(0.84),vec2(1.0),p));
	vec3 a=texture(stone,p).rgb;
	vec3 b=texture(stone,fract(p+vec2(0.5,0.0))).rgb;
	vec3 c=texture(stone,fract(p+vec2(0.0,0.5))).rgb;
	vec3 d=texture(stone,fract(p+vec2(0.5))).rgb;
	return mix(mix(d,c,w.x),mix(b,a,w.x),w.y);
}
void fragment() {
	vec4 edge=texture(TEXTURE,UV);
	// Opposite source borders are not tileable. At each boundary, transition
	// to a continuous interior region of that same source. No mirrored motifs.
	vec2 field=world_position/128.0;
	field+=vec2(0.25*sin(world_position.y/91.0),0.24*sin(world_position.x/137.0));
	float blend=smoothstep(-0.4,0.4,sin(world_position.x/151.0+sin(world_position.y/87.0)));
	vec3 rock=mix(field_at(field),field_at(field+vec2(0.37,0.23)),blend);
	float local_y=mod(UV.y*float(textureSize(TEXTURE,0).y)-2.0,68.0)/64.0;
	float lip=tint.r*(1.0-smoothstep(0.04,0.25,local_y));
	COLOR=vec4(mix(rock,edge.rgb,lip),edge.a);
}

