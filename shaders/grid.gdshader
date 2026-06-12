shader_type spatial;
render_mode cull_back;

// World-space grid. Lines are computed from world XZ, so the spacing stays a
// true 1 m regardless of how the floor mesh is scaled.

uniform vec3 base_color : source_color = vec3(0.30, 0.33, 0.38);
uniform vec3 line_color : source_color = vec3(0.55, 0.62, 0.75);
uniform vec3 major_color : source_color = vec3(0.85, 0.90, 1.0);
uniform float cell_size = 1.0;        // metres per cell
uniform float major_every = 10.0;     // a brighter line every N cells
uniform float line_thickness = 1.0;   // in pixels (derivative units)
uniform float roughness_val = 0.9;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// Anti-aliased line mask: ~constant pixel width at any distance.
float grid_factor(vec2 coord, float thickness) {
	vec2 d = fwidth(coord);
	vec2 g = abs(fract(coord - 0.5) - 0.5) / max(d, vec2(1e-5)) / thickness;
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void fragment() {
	vec2 p = world_pos.xz;
	float minor = grid_factor(p / cell_size, line_thickness);
	float major = grid_factor(p / (cell_size * major_every), line_thickness * 1.5);
	vec3 col = base_color;
	col = mix(col, line_color, minor);
	col = mix(col, major_color, major);
	ALBEDO = col;
	ROUGHNESS = roughness_val;
	METALLIC = 0.0;
}
