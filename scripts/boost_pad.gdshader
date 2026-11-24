shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque;
// Boost pad: bright chevrons (>>) pointing along -Z (the direction of travel) that scroll forward.
uniform vec4 base_col : source_color = vec4(1.0, 0.5, 0.05, 1.0);
uniform vec4 chev_col : source_color = vec4(1.0, 0.97, 0.55, 1.0);
uniform float count = 3.0;     // chevrons along the pad
uniform float slope = 0.9;     // how pointed each chevron is
uniform float width = 0.32;    // stripe thickness (0..1 of a period)
uniform float speed = 1.6;     // scroll speed (periods per second)
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	// pad mesh is 2.6 wide (x) and 3.2 long (z); forward = -z
	float x = lp.x / 1.3;              // -1..1 across
	float fwd = (-lp.z / 3.2) + 0.5;   // 0 at the back edge, 1 at the front edge
	float p = fract((fwd + slope * abs(x) * 0.5) * count - TIME * speed);
	float stripe = smoothstep(0.0, 0.06, p) * (1.0 - smoothstep(width, width + 0.06, p));
	float edge = 1.0 - smoothstep(0.86, 1.0, abs(x));   // soft side borders
	float pulse = 0.85 + 0.15 * sin(TIME * 6.0);
	vec3 c = mix(base_col.rgb * 0.9, chev_col.rgb * 1.4 * pulse, stripe * edge);
	// darker rim so the pad reads on bright tarmac
	float rim = max(smoothstep(0.9, 1.0, abs(x)), smoothstep(0.93, 1.0, abs(fwd * 2.0 - 1.0)));
	ALBEDO = mix(c, base_col.rgb * 0.45, rim);
}
