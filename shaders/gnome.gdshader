shader_type spatial;

// --- Textures ---
uniform sampler2D albedo_texture : source_color;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D orm_texture : hint_default_white; // AO, Roughness, Metallic

// --- Replacement Settings ---
uniform vec4 blue_replacement_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float threshold : hint_range(0.0, 0.5) = 0.05;

// --- Material Tweaks ---
uniform float metallic_strength : hint_range(0.0, 1.0) = 1.0;
uniform float roughness_strength : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    // 1. SAMPLE ALL TEXTURES
    vec4 tex_color = texture(albedo_texture, UV);
    vec3 normal_map = texture(normal_texture, UV).rgb;
    vec3 orm = texture(orm_texture, UV).rgb; // R = AO, G = Roughness, B = Metallic

    vec3 color = tex_color.rgb;
    
    // 2. BLUE DOMINANCE LOGIC
    float max_channel = max(color.r, max(color.g, color.b));
    
    if (color.b == max_channel && color.b > color.r + threshold && color.b > color.g + threshold) {
        // Swap color but keep the brightness (value) of the original texture
        ALBEDO = blue_replacement_color.rgb * color.b;
    } else {
        ALBEDO = color;
    }

    // 3. APPLY PBR PROPERTIES
    // Normal mapping
    NORMAL_MAP = normal_map;
    
    // Ambient Occlusion, Roughness, and Metallic
    // We use the strengths to multiply the values from your texture map
    AO = orm.r;
    ROUGHNESS = orm.g * roughness_strength;
    METALLIC = orm.b * metallic_strength;
    
    // Alpha transparency
    ALPHA = tex_color.a;
}