shader_type canvas_item;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment() {
	vec4 color=texture(TEXTURE,UV)*tint;
	// Local alpha repair of the cropped upper edge, over 18 world units.
	// No blur, dimming or change to the rock/foliage detail.
	color.a*=smoothstep(0.0,0.06,UV.y);
	COLOR=color;
}
