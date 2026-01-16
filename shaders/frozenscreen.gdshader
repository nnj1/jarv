shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_img : repeat_enable; // SET THIS TO CELLULAR NOISE

uniform float frost_amount : hint_range(0.0, 1.0) = 0.0;
uniform float max_opacity : hint_range(0.0, 1.0) = 0.8;
uniform float crack_intensity : hint_range(0.0, 0.5) = 0.1;
uniform vec4 frost_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);

void fragment() {
    // 1. Distance mask (The Creep)
    vec2 center_dist = abs(UV - 0.5) * 2.0;
    float dist = max(center_dist.x, center_dist.y);

    // 2. Sample Noise
    float noise = texture(noise_img, UV).r;

    // 3. Creep Logic
    float soft_edge = 0.3;
    float threshold = mix(1.3, -0.3, frost_amount);
    float mask = smoothstep(threshold, threshold + soft_edge, dist + (noise * 0.3));
    mask *= smoothstep(0.0, 0.02, frost_amount);

    // 4. Cracked Glass Distortion
    // Instead of smooth waving, we use the noise to create "displacements"
    // This makes the background look like it's broken into shards
    vec2 shard_offset = (vec2(noise) - 0.5) * crack_intensity * mask;

    // 5. Screen Capture with "Fractured" UVs
    // We sample with the shard_offset to create the broken glass look
    float blur = mask * 2.5;
    vec4 screen_content = textureLod(SCREEN_TEXTURE, SCREEN_UV + shard_offset, blur);

    // 6. Highlight the "Cracks"
    // We use a high-contrast version of the noise to draw white lines on the cracks
    float crack_lines = smoothstep(0.4, 0.5, noise) * smoothstep(0.6, 0.5, noise);

    vec3 final_rgb = mix(screen_content.rgb, frost_color.rgb, 0.3 * mask);
    final_rgb += crack_lines * mask * 0.4; // Draws the bright edges of the cracks
    final_rgb += (noise * 0.1) * mask;     // General icy sheen

    COLOR = vec4(final_rgb, mask * max_opacity);
}