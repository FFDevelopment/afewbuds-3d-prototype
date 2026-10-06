shader_type spatial;
render_mode diffuse_burley;
varying vec3 bark_position;
varying vec3 bark_normal;
void vertex() {
 bark_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 bark_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float across=abs(bark_normal.z)>abs(bark_normal.x)?bark_position.x:bark_position.z;
 float warp=noise(vec2(across*8.0,bark_position.y*1.2))*0.7;
 float ridges=noise(vec2(across*65.0+warp,bark_position.y*1.7));
 float cracks=smoothstep(0.24,0.36,ridges);
 vec3 brown=mix(vec3(0.12,0.065,0.033),vec3(0.35,0.22,0.12),ridges);
 ALBEDO=brown*mix(0.52,1.0,cracks)*(0.88+0.18*noise(bark_position.xy*95.0));
 ROUGHNESS=0.96;
 SPECULAR=0.12;
}
