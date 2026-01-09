// NOTE: Shader automatically converted and modified for damage.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

// --- Original Uniforms ---
uniform vec4 albedo : source_color;
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform ivec2 albedo_texture_size;
uniform float point_size : hint_range(0.1, 128.0, 0.1);
uniform float roughness : hint_range(0.0, 1.0);
uniform sampler2D texture_metallic : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec4 metallic_texture_channel;
uniform sampler2D texture_roughness : hint_roughness_g, filter_linear_mipmap, repeat_enable;
uniform float specular : hint_range(0.0, 1.0, 0.01);
uniform float metallic : hint_range(0.0, 1.0, 0.01);
uniform sampler2D texture_emission : source_color, hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec4 emission : source_color;
uniform float emission_energy : hint_range(0.0, 100.0, 0.01);
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

// --- Damage Uniforms ---
uniform float damage_amount : hint_range(0.0, 1.0) = 0.0;
uniform float crumple_scale = 4.0;
uniform float crumple_strength = 0.4;
uniform vec4 scrap_metal_color : source_color = vec4(0.4, 0.4, 0.4, 1.0);

// --- Noise Functions ---
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
	UV = UV * uv1_scale.xy + uv1_offset.xy;
	
	// Apply deformation
	if (damage_amount > 0.0) {
		float n = noise(VERTEX * crumple_scale);
		// Moves vertices inward/outward along their normal
		float displacement = (n - 0.5) * crumple_strength * damage_amount;
		VERTEX += NORMAL * displacement;
	}
}

void fragment() {
	vec2 base_uv = UV;

	// 1. Calculate the damage/scratch mask based on the mesh geometry
	// We use the same noise logic to ensure scratches appear on dented areas
	float n = noise(VERTEX * crumple_scale * 2.0);
	float scrap_mask = smoothstep(1.0 - (damage_amount * 0.5), 1.0, n * damage_amount);

	// 2. Albedo logic (Modified to include scratches)
	vec4 albedo_tex = texture(texture_albedo, base_uv);
	vec3 final_albedo = albedo.rgb * albedo_tex.rgb;
	ALBEDO = mix(final_albedo, scrap_metal_color.rgb, scrap_mask);

	// 3. Metallic/Specular logic (Modified to make scratches metallic)
	float metallic_tex = dot(texture(texture_metallic, base_uv), metallic_texture_channel);
	METALLIC = mix(metallic_tex * metallic, 1.0, scrap_mask);
	SPECULAR = specular;

	// 4. Roughness logic (Modified to make scratches rougher)
	vec4 roughness_texture_channel = vec4(0.0, 1.0, 0.0, 0.0);
	float roughness_tex = dot(texture(texture_roughness, base_uv), roughness_texture_channel);
	ROUGHNESS = mix(roughness_tex * roughness, 0.9, scrap_mask);

	// 5. Emission: (Modified to "break" lights as damage increases)
	vec3 emission_tex = texture(texture_emission, base_uv).rgb;
	float emission_flicker = smoothstep(0.9, 0.3, damage_amount * n);
	EMISSION = ((emission.rgb + emission_tex) * emission_energy) * emission_flicker;
}