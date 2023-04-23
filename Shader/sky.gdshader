shader_type sky;

uniform vec3 skyColor: source_color;
uniform vec3 horizonColor: source_color;
uniform sampler2D skyTEXTURE;

void sky() {
//	float col = clamp(EYEDIR.y / 0.2, 0.0, 1.0);
//	vec3 finalColor = mix(horizonColor,skyColor,col);
	COLOR = texture(skyTEXTURE,SKY_COORDS).rgb;
	// Place sky code here.
}
