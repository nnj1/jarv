shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 wire_color : source_color = vec4(0.0, 0.216, 1.0, 0.113);
uniform float wire_width : hint_range(0.0, 4.0) = 1.0;
uniform bool is_active = false;

void fragment() {
    if (!is_active) {
        discard;
    }

    // This creates a wireframe effect based on the UV coordinates
    // It works best on meshes with clean, non-overlapping UVs
    vec2 uv_deriv = fwidth(UV);
    vec2 line_grid = smoothstep(uv_deriv * (wire_width - 0.5), uv_deriv * (wire_width + 0.5), UV);
    vec2 line_grid_inv = smoothstep(uv_deriv * (wire_width - 0.5), uv_deriv * (wire_width + 0.5), 1.0 - UV);
    
    float edge = 1.0 - (min(min(line_grid.x, line_grid.y), min(line_grid_inv.x, line_grid_inv.y)));

    if (edge < 0.1) {
        discard; // Remove the "faces" so the PBR pass shows through
    }

    ALBEDO = wire_color.rgb;
    ALPHA = wire_color.a;
}