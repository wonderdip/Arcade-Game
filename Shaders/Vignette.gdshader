shader_type canvas_item;

uniform float vignette_intensity = 0.4;
uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;
uniform vec4 vignette_rgb : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform bool overlay_mode = false; // Toggle: false = classic, true = overlay

float vignette(vec2 uv) {
	uv = uv * (1.0 - uv); // soft radial falloff
	float v = uv.x * uv.y * 15.0;
	return pow(v, vignette_intensity * vignette_opacity);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float v = vignette(UV);
	vec3 final_rgb = vignette_rgb.rgb;

	if (overlay_mode) {
		// Overlay mode: center transparent, edges opaque
		float alpha = clamp(1.0 - v, 0.0, 1.0);
		COLOR = vec4(final_rgb, alpha);
	} else {
		// Classic vignette: blend texture toward vignette color
		vec3 blended = mix(final_rgb, tex.rgb, v);
		COLOR = vec4(blended, tex.a);
	}
}
