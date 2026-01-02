shader_type spatial;

// depth_draw_always forces Godot to check depth for every single pixel 
// cull_back hides the interior faces
render_mode cull_back, depth_draw_always, diffuse_burley, specular_schlick_ggx;

// --- BOUNCY SETTINGS ---
uniform float bounce_speed : hint_range(0.1, 10.0) = 3.0;
uniform float bounce_height : hint_range(0.0, 5.0) = 0.5;
uniform float squash_amount : hint_range(0.0, 1.0) = 0.2;

// --- TEXTURE SLOTS ---
uniform sampler2D albedo_texture : source_color;
uniform sampler2D normal_texture : hint_normal;
uniform sampler2D orm_texture : hint_default_white; 

// --- COLOR SWAP SETTINGS ---
uniform vec4 blue_replacement_color : source_color = vec4(1.0, 1.0, 0.0, 1.0);
uniform float threshold : hint_range(0.0, 0.5) = 0.05;

void vertex() {
    float local_time = mod(TIME, 62.8318); 
    float bounce = abs(sin(local_time * bounce_speed));
    
    // We increase the minimum squash to 0.4. 
    // If squash is too low (e.g., 0.1), the model becomes 
    // so thin that the front and back faces touch, causing "ghosting."
    float squash = 1.0 + (bounce - 0.5) * squash_amount;
    squash = max(squash, 0.4); 
    
    // Apply deformation logic
    VERTEX.y += bounce * bounce_height;
    VERTEX.y *= squash;
    VERTEX.x /= squash;
    VERTEX.z /= squash;
    
    // Recalculate normals so lighting doesn't reveal internal triangles
    NORMAL = normalize(NORMAL * vec3(1.0/squash, squash, 1.0/squash));
}

void fragment() {
    vec4 tex_color = texture(albedo_texture, UV);
    
    // Check for transparency - if your texture has holes, 
    // the back will show through. This line prevents that.
    if (tex_color.a < 0.1) {
        discard;
    }

    vec3 color = tex_color.rgb;
    float max_channel = max(color.r, max(color.g, color.b));
    
    if (color.b == max_channel && color.b > color.r + threshold && color.b > color.g + threshold) {
        ALBEDO = blue_replacement_color.rgb * color.b;
    } else {
        ALBEDO = color;
    }

    NORMAL_MAP = texture(normal_texture, UV).rgb;
    vec3 orm = texture(orm_texture, UV).rgb; 
    AO = orm.r;
    ROUGHNESS = orm.g;
    METALLIC = orm.b;
    ALPHA = tex_color.a;
}