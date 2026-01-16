shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.5;
uniform vec4 fill_color : source_color = vec4(0.8, 0.2, 0.2, 1.0);
uniform vec4 back_fill_color : source_color = vec4(0.6, 0.1, 0.1, 1.0); // Darker shade
uniform vec4 background_color : source_color = vec4(0.1, 0.1, 0.1, 1.0);
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

uniform float border_thickness : hint_range(0.0, 0.2) = 0.05;
uniform float edge_softness : hint_range(0.001, 0.05) = 0.01;

// Wave controls
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.015;
uniform float wave_speed : hint_range(0.0, 10.0) = 2.0;
uniform float wave_frequency : hint_range(0.0, 20.0) = 12.0;

float heart(vec2 uv) {
	uv = uv * 2.0 - vec2(1.0);
	uv.y *= -1.0;
	uv.y -= 0.01;

	float x = uv.x;
	float y = uv.y;
	float a = x * x + y * y - 0.23;
	return a * a * a - x * x * y * y * y;
}

void fragment() {
	vec2 uv = UV;
	float h = heart(uv);
	
	if (h > 0.0)
		discard;

	// Calculate two different waves
	// Wave 1: Front wave
	float wave1 = sin(uv.x * wave_frequency + TIME * wave_speed) * wave_amplitude;
	// Wave 2: Back wave (offset frequency and negative speed)
	float wave2 = sin(uv.x * (wave_frequency * 0.8) - TIME * (wave_speed * 0.7)) * wave_amplitude;
	
	float bottom_edge = 0.82;
	float top_edge = 0.18;
	float base_threshold = mix(bottom_edge, top_edge, progress);

	// Start with the background
	vec4 color = background_color;

	// Layer 1: Back Wave
	if (uv.y >= base_threshold + wave2) {
		color = back_fill_color;
	}
    
	// Layer 2: Front Wave (Overwrites back wave)
	if (uv.y >= base_threshold + wave1) {
		color = fill_color;
	}

	// Border smoothing
	float edge = smoothstep(-edge_softness, edge_softness, h + border_thickness);
	color = mix(border_color, color, edge);

	COLOR = color;
}