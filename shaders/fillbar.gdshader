shader_type canvas_item;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 color_empty : source_color = vec4(0.1, 0.1, 0.1, 1.0); // Dark Gray
uniform vec4 color_full : source_color = vec4(0.0, 0.6, 1.0, 1.0);  // Blue

void fragment() {
    // texture(TEXTURE, UV) keeps your texture's shape/detail
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Mix linearly between the two colors based on the fill percentage
    vec4 final_color = mix(color_empty, color_full, fill);
    
    // Apply the colors to the texture (multiplication keeps shadows/transparency)
    COLOR = final_color * tex_color;
}