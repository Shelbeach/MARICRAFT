shader_type canvas_item;
// Re-light the existing iron teeth, retaining their painted facets and rusted foot.
void fragment() {
	vec4 paint = texture(TEXTURE, UV);
	float luminance = dot(paint.rgb, vec3(0.2126, 0.7152, 0.0722));
	float teeth = 1.0 - smoothstep(0.72, 0.88, UV.y);
	vec3 metal = mix(vec3(0.42, 0.44, 0.43), vec3(1.0, 0.96, 0.80), smoothstep(0.04, 0.48, luminance));
	paint.rgb = mix(paint.rgb, metal, 0.92 * teeth);
	COLOR = paint;
}
