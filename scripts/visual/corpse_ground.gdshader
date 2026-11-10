shader_type canvas_item;
uniform float floor_y = 480.0;
varying float world_y;
void vertex() { world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y; }
void fragment() { if (world_y > floor_y + 1.0) { discard; } }
