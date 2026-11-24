shader_type canvas_item;
// Full-screen FX overlay (FX_MASTERPLAN.md §5.1), the FxScreen node in duel_ui.tscn.
// Covers the 3D view and the HUD, with or without the pixel filter. FxDirector hides the node
// when every value is 0, so it costs nothing (not even the screen copy) between effects.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
// Flash: color mixed over the screen with this alpha.
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
// Drain color towards gray (0 = none, 1 = full gray).
uniform float desat : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	// Warm gray, closer to the palette's ink than a cold neutral.
	col = mix(col, vec3(l) * vec3(1.04, 1.0, 0.94), desat);
	col = mix(col, flash_color.rgb, flash);
	COLOR = vec4(col, 1.0);
}
