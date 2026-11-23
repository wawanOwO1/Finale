shader_type spatial;
// Pixel filter post-process (ART_DIRECTION §2): a full-screen quad in front of the stage camera.
// The 3D view is already rendered low-res (SubViewportContainer.stretch_shrink, nearest upscale);
// this adds the chunky look on top: dark outlines from depth jumps (after leopeltola's
// Godot-3d-pixelart-demo, MIT) and a posterized palette with a small ordered dither.
// Works in Compatibility (only the depth + screen textures, no normal buffer).
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

uniform bool outlines = true;
// How much darker an outline pixel gets (0 = none, 1 = black).
uniform float outline_strength : hint_range(0.0, 1.0) = 0.7;
// Depth jump (world units) that counts as an edge.
uniform float outline_threshold : hint_range(0.01, 2.0) = 0.15;
uniform vec3 outline_tint : source_color = vec3(0.23, 0.14, 0.08);
// Color levels per channel (lower = flatter, more "pixel art").
uniform float color_levels : hint_range(2.0, 64.0) = 12.0;
// Ordered dither between levels (0 = hard bands).
uniform float dither : hint_range(0.0, 1.0) = 0.2;
// Pushes colors a bit warmer and punchier, like the reference palette.
uniform float saturation : hint_range(0.0, 2.0) = 1.1;
// Debug: show linear depth (fract of depth / 10) instead of the image.
uniform bool debug_depth = false;

void vertex() {
	// Cover the whole screen whatever the camera does.
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

float linear_depth(vec2 uv, mat4 inv_proj) {
	float d = texture(depth_tex, uv).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv * 2.0 - 1.0, d * 2.0 - 1.0);
#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, d);
#endif
	vec4 view = inv_proj * vec4(ndc, 1.0);
	return -view.z / view.w;
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return m[i] / 16.0 - 0.5;
}

void fragment() {
	vec2 texel = 1.0 / VIEWPORT_SIZE;
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;

	if (outlines) {
		float d = linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX);
		// Edge where a neighbour is clearly in front of this pixel: the outline sits on the far side.
		float edge = 0.0;
		vec2 offs[4] = vec2[](vec2(texel.x, 0.0), vec2(-texel.x, 0.0), vec2(0.0, texel.y), vec2(0.0, -texel.y));
		for (int i = 0; i < 4; i++) {
			float n = linear_depth(SCREEN_UV + offs[i], INV_PROJECTION_MATRIX);
			edge = max(edge, clamp((d - n - outline_threshold * (1.0 + d * 0.05)) * 4.0, 0.0, 1.0));
		}
		col = mix(col, outline_tint, edge * outline_strength);
	}

	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(l), col, saturation);
	float steps = color_levels - 1.0;
	col = floor(col * steps + 0.5 + bayer4(FRAGCOORD.xy) * dither) / steps;
	ALBEDO = clamp(col, 0.0, 1.0);
	if (debug_depth) {
		ALBEDO = vec3(fract(linear_depth(SCREEN_UV, INV_PROJECTION_MATRIX) / 10.0));
	}
}
