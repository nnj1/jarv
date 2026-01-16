shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D noise_img : repeat_enable;

uniform float frost_amount : hint_range(0.0, 1.0) = 0.0;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;
uniform vec4 frost_color : source_color = vec4(0.85, 0.92, 1.0, 1.0);

void fragment() {
    // 1. Calculate base distance from edges (0 at center, 1 at edges)
    vec2 center_dist = abs(UV - 0.5) * 2.0;
    float dist = max(center_dist.x, center_dist.y);

    // 2. Sample noise
    float noise = texture(noise_img, UV).r;

    // 3. Robust Masking Logic
    // This ensures that when frost_amount is 0, 'mask' is strictly 0.
    float mask = smoothstep(1.0 - frost_amount, 1.1 - frost_amount, dist + (noise * 0.15));
    mask = clamp(mask * sign(frost_amount), 0.0, 1.0);

    // 4. Screen Distortion (Refraction)
    // Only distort where the mask > 0
    vec2 distortion = (vec2(noise) - 0.5) * distortion_strength * mask;

    // 5. Blur Effect (using lod)
    // Higher frost = more blur at the edges
    float blur_value = mask * 3.0 * frost_amount;
    vec4 screen_content = textureLod(SCREEN_TEXTURE, SCREEN_UV + distortion, blur_value);

    // 6. Color Mixing
    // Add a bit of white "frosting" and mix with screen
    vec3 ice_tint = mix(screen_content.rgb, frost_color.rgb, mask * 0.3);
    float crystals = pow(noise, 3.0) * mask; // Bright white highlights

    COLOR = vec4(ice_tint + crystals, 1.0);
}