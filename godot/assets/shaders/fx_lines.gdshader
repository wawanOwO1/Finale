shader_type canvas_item;
// Procedural manga speed lines (FX_MASTERPLAN.md §5.3), the FxLines node in duel_ui.tscn.
// No texture. mode 0 = radial focus lines around `center`, 1 = horizontal dash lines,
// 2 = shockwave ring growing from `center`. Drawn on the 3 px art grid so it stays pixel art.
// FxDirector hides the node when alpha is 0.

uniform int mode = 0;
uniform float alpha : hint_range(0.0, 1.0) = 0.0;
uniform vec4 ink : source_color = vec4(0.231, 0.141, 0.078, 1.0);
// Focus point in UV (0..1 of the rect).
uniform vec2 center = vec2(0.5);
// Rect size in screen px (aspect + pixel grid).
uniform vec2 rect_px = vec2(1920.0, 1080.0);
uniform float pixel = 3.0;
// Changes a few times a second: the lines jitter like hand-drawn frames.
uniform float seed = 0.0;
// Number of radial lines / horizontal rows.
uniform float count = 90.0;
// Clear area around the focus (radial), as a fraction of the screen height.
uniform float inner = 0.32;
// Ring progress 0..1 (mode 2).
uniform float progress = 0.0;

float hash(float n) {
	return fract(sin(n * 127.1 + seed * 311.7) * 43758.5453);
}

void fragment() {
	vec2 px = floor(UV * rect_px / pixel) * pixel + pixel * 0.5;
	vec2 p = (px - center * rect_px) / rect_px.y;
	float a = 0.0;
	if (mode == 0) {
		float ang = atan(p.y, p.x) / 6.2831853 + 0.5;
		float slot = floor(ang * count);
		float f = fract(ang * count);
		float w = 0.15 + 0.45 * hash(slot);
		float start = inner * (0.75 + 0.6 * hash(slot + 17.0));
		float r = length(p);
		float on = step(0.45, hash(slot + 3.0)) * step(abs(f - 0.5), w * 0.5);
		// Lines taper: thin near the focus, full at the edge.
		a = on * smoothstep(start, start + 0.12, r);
	} else if (mode == 1) {
		float row = floor(UV.y * count);
		float h = hash(row);
		float len = 0.25 + 0.5 * hash(row + 5.0);
		float x0 = hash(row + 9.0);
		float x = fract(UV.x - x0 + seed * 0.37);
		a = step(0.55, h) * step(x, len) * smoothstep(0.0, len * 0.3, x);
	} else {
		float r = length(p);
		float rad = progress * 1.2;
		float band = 0.05 * (1.0 - progress) + 0.01;
		a = step(abs(r - rad), band) * (1.0 - progress);
	}
	COLOR = vec4(ink.rgb, ink.a * a * alpha);
}
