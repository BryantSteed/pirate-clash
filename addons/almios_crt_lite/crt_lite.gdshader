shader_type canvas_item;

// CRT Lite (free) by Dimension Almios, MIT licence.
// A light CRT look for the whole screen: curved glass with rounded corners,
// scanlines, vignette, an optional RGB mask, colour settings, a one-colour monitor
// mode and a little life (grain, flicker, a rolling bar, a glass reflection).
// CRTLite (crt_lite.gd) sets it up in one node, with presets. Put it on a ColorRect that covers
// the screen, inside a CanvasLayer drawn above your game (layer 100, for
// example): it reads what is already on screen. Anything on a higher layer (your
// interface, if you like) stays clean.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

uniform float curvature : hint_range(0.0, 0.3) = 0.1;       // 0 = flat screen
uniform float corner_radius : hint_range(0.0, 0.3) = 0.06;  // as a fraction of the screen height
uniform vec4 border_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
group_uniforms Scanlines;
uniform float scanlines : hint_range(0.0, 1.0) = 0.35;      // how dark the gaps between lines are
uniform float scanline_size : hint_range(2.0, 8.0) = 3.0;   // height of one line, in screen pixels
group_uniforms Look;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float brightness : hint_range(0.5, 2.0) = 1.1;      // makes up for the darker gaps
uniform bool rgb_mask = false;                               // red, green and blue phosphors like a real tube
uniform float mask_strength : hint_range(0.0, 1.0) = 0.3;
uniform int mask_type : hint_range(0, 1) = 0;                // 0 vertical stripes, 1 staggered dots
group_uniforms Color;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;
uniform float contrast : hint_range(0.5, 2.0) = 1.0;
uniform float warmth : hint_range(-1.0, 1.0) = 0.0;          // + warmer (old TV), - cooler
// a one-colour monitor: 0 off, 1 fully in the phosphor colour (green, amber, white...)
uniform float monochrome : hint_range(0.0, 1.0) = 0.0;
uniform vec4 phosphor_color : source_color = vec4(0.35, 1.0, 0.45, 1.0);
group_uniforms Life;
uniform float noise : hint_range(0.0, 1.0) = 0.0;            // moving grain
uniform float flicker : hint_range(0.0, 1.0) = 0.0;          // the brightness breathes a little
uniform float rolling_bar : hint_range(0.0, 1.0) = 0.0;      // a soft bright band that scrolls down
uniform float glass_reflection : hint_range(0.0, 1.0) = 0.0; // a soft sheen on the curved glass

float hash(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

void fragment() {
	vec4 node_tint = COLOR;
	vec2 screen_px = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = screen_px.x / screen_px.y;

	// barrel curvature: each axis bends by the square of the other, so the edges
	// bow inward and the corners fall off the glass
	vec2 cc = SCREEN_UV * 2.0 - 1.0;
	vec2 bent = cc + cc * cc.yx * cc.yx * curvature;
	bent *= 1.0 + curvature * 0.25;   // a little overscan: a thin frame shows all round
	vec2 uv = bent * 0.5 + 0.5;

	// the glass: a rounded rectangle, anti-aliased by its own screen-space slope
	vec2 half_size = vec2(aspect, 1.0);
	vec2 p = bent * half_size;
	float rad = corner_radius;
	vec2 q = abs(p) - (half_size - rad);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
	float inside = clamp(0.5 - d / max(fwidth(d), 1e-5), 0.0, 1.0);

	vec3 col = textureLod(screen_tex, clamp(uv, 0.0, 1.0), 0.0).rgb;

	// scanlines are laid on the screen's own pixel rows: every line has the same
	// height and a soft cosine profile, so they never beat into moire bands
	// (FRAGCOORD is a pixel centre, k + 0.5: without the half pixel, a size of 2 would
	// put every row on the zero of the cosine and the lines would vanish)
	float line = (FRAGCOORD.y - 0.5) / scanline_size;
	float s = 0.5 + 0.5 * cos(line * 6.2832);
	// bright pixels bloom across the gap, like a real beam
	float lum = dot(col, vec3(0.3, 0.59, 0.11));
	col *= mix(1.0, mix(1.0 - scanlines, 1.0, s), 1.0 - lum * 0.4);

	// colour: contrast around mid grey, saturation, warmth, then the one-colour tube
	col = (col - 0.5) * contrast + 0.5;
	float grey = dot(col, vec3(0.3, 0.59, 0.11));
	col = mix(vec3(grey), col, saturation);
	col *= vec3(1.0 + warmth * 0.12, 1.0 + warmth * 0.02, 1.0 - warmth * 0.12);
	// a phosphor lights up with a curve: darks stay near black, brights reach the
	// full colour with a whiter core, so a light scene keeps its shapes
	float g = clamp(grey, 0.0, 1.0);
	vec3 mono = phosphor_color.rgb * pow(g, 1.8) * 1.15 + vec3(1.0) * pow(g, 6.0) * 0.25;
	col = mix(col, mono, monochrome);
	col = max(col, vec3(0.0));

	if (rgb_mask) {
		// stripes: one phosphor per screen column; dots: the rows are offset by
		// half a triad, like a shadow mask
		float x = FRAGCOORD.x;
		if (mask_type == 1) {
			x += mod(floor(FRAGCOORD.y / 2.0), 2.0) * 1.5;
		}
		float k = mod(floor(x), 3.0);
		vec3 m = k < 1.0 ? vec3(1.0, 0.7, 0.7) : (k < 2.0 ? vec3(0.7, 1.0, 0.7) : vec3(0.7, 0.7, 1.0));
		if (mask_type == 1) {
			m *= 0.85 + 0.15 * step(0.5, mod(FRAGCOORD.y, 2.0));
		}
		col *= mix(vec3(1.0), m * 1.18, mask_strength);
	}

	// life: the tube is never perfectly still
	float t = TIME;
	col *= 1.0 - flicker * 0.06 * (0.5 + 0.5 * sin(t * 43.0) * sin(t * 7.3));
	float bar = fract(uv.y * 0.6 - t * 0.12);
	col += col * rolling_bar * 0.18 * exp(-pow((bar - 0.5) / 0.08, 2.0));
	col += (hash(FRAGCOORD.xy + fract(t * 13.7) * 91.0) - 0.5) * noise * 0.12;

	vec2 v = uv * (1.0 - uv);
	col *= mix(1.0, pow(clamp(v.x * v.y * 16.0, 0.0, 1.0), 0.3), vignette);
	col *= brightness;
	// a soft reflection on the glass, brighter toward the top left, following the curve
	float sheen = exp(-dot(bent - vec2(-0.55, -0.6), bent - vec2(-0.55, -0.6)) * 2.2);
	col += vec3(0.9, 0.95, 1.0) * sheen * glass_reflection * 0.12;
	col += (hash(FRAGCOORD.xy) - 0.5) / 255.0;                 // dither: no banding in the vignette

	COLOR = vec4(mix(border_color.rgb, col, inside), 1.0);
	COLOR *= node_tint;
}
