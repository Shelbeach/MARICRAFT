shader_type canvas_item;
uniform sampler2D field: filter_linear, repeat_enable;
uniform sampler2D transition_field: filter_linear, repeat_enable;
uniform bool use_transition=false;
uniform float transition_start=1536.0;
varying vec2 world_position;
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
	vec2 pixel=UV*vec2(textureSize(TEXTURE,0));
	float phase=floor(pixel.y/68.0);
	vec2 local=mod(pixel-2.0,68.0)/64.0;
	vec2 source=(vec2(mod(phase,8.0),floor(phase/8.0))+local)/8.0;
	vec4 edge=texture(TEXTURE,UV);
	vec3 base=texture(field,source).rgb;
	vec3 fill=texture(field,world_position/256.0).rgb;
	if(use_transition && world_position.x>=transition_start) {
		fill=texture(transition_field,vec2(clamp((world_position.x-transition_start)/256.0,0.001,0.999),world_position.y/256.0)).rgb;
	}
	COLOR=vec4(clamp(fill+edge.rgb-base,0.0,1.0),edge.a);
}
