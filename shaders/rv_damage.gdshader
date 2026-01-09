shader_type spatial;

// --- Standard Maps ---
uniform sampler2D albedo_map : source_color;
uniform sampler2D metallic_map : hint_default_white;
uniform sampler2D roughness_map : hint_default_white;
uniform sampler2D emission_map : hint_default_black;

// --- Damage Parameters ---
uniform float damage_amount : hint_range(0.0, 1.0) = 0.0;
uniform float crumple_scale = 4.0;
uniform float crumple_strength = 0.2;
uniform vec3 scrap_metal_color : source_color = vec3(0.4, 0.4, 0.4);

// Simple 3D noise for vertex & fragment
float hash(vec3 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
    vec3 i = floor(x);
    vec3 f = fract(x);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
                   mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
               mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
                   mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
    // Apply vertex deformation based on noise and damage level
    float n = noise(VERTEX * crumple_scale);
    float displacement = (n - 0.5) * crumple_strength * damage_amount;
    VERTEX += NORMAL * displacement;
}

void fragment() {
    // 1. Sample Original Textures
    vec4 tex_albedo = texture(albedo_map, UV);
    float tex_metallic = texture(metallic_map, UV).r;
    float tex_roughness = texture(roughness_map, UV).r;
    vec3 tex_emission = texture(emission_map, UV).rgb;
    
    // 2. Calculate Damage Mask for the Fragment (Paint scraping)
    // We use a higher scale noise for fine-detail scratches
    float scrap_n = noise(VERTEX * crumple_scale * 3.0);
    float scrap_mask = smoothstep(1.1 - damage_amount, 1.0, scrap_n);
    
    // 3. Mix Results
    // Albedo fades to scrap metal where damaged
    ALBEDO = mix(tex_albedo.rgb, scrap_metal_color, scrap_mask);
    
    // Scraped areas become more metallic and rougher
    METALLIC = mix(tex_metallic, 1.0, scrap_mask);
    ROUGHNESS = mix(tex_roughness, 0.8, scrap_mask);
    
    // 4. Damage Emission (Headlights "breaking")
    // If damage is high, reduce emission intensity
    float emission_fail = smoothstep(0.8, 0.2, damage_amount * scrap_n);
    EMISSION = tex_emission * emission_fail;
}