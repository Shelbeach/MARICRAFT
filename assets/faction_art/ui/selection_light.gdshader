shader_type canvas_item;
render_mode unshaded;
void fragment(){
 vec2 p=(UV-vec2(0.5,0.67))/vec2(0.5,0.66);
 COLOR.a*=pow(clamp(1.0-dot(p,p),0.0,1.0),2.0);
}
