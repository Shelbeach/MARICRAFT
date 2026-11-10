shader_type canvas_item;
uniform sampler2D pool : filter_linear;
uniform vec2 origin_world;
uniform vec2 extent;
uniform float age = 0.0;
void fragment() {
    vec2 world = origin_world + UV * extent;
    // Sample the painted opaque interior. Mirrored sampling joins without alpha
    // caps or hard seams; coordinates are world-anchored as the camera moves.
    float u = 1.0 - abs(fract((world.x + age * 5.0) / 246.0) * 2.0 - 1.0);
    float v = 0.255 + min(UV.y * extent.y / 160.0, 0.26);
    vec3 paint = texture(pool, vec2(0.22 + u * 0.56, v)).rgb;
    float crest = (1.0 - smoothstep(0.5, 3.0, UV.y * extent.y));
    paint = mix(paint, vec3(1.0, 0.66, 0.20), crest * 0.65);
    COLOR = vec4(paint, 1.0);
}
