@group(0) @binding(0) var g_texture: texture_2d<f32>;
@group(1) @binding(0) var g_sampler: sampler;

struct GlassProps {
	// 32 padding
    padding: array<f32, 8>,

	center: vec2<f32>,
	size: vec2<f32>,

    // glass parameters
    elipse_strength: f32,
    exponent_offset: f32,
    decay_scale: f32,
	base_factor: f32,
	deca_rate: f32,
	refraction_falloff: f32,

	noise: f32,

	glow_weight: f32,
    glow_bias: f32,
    glow_edge0: f32,
    glow_edge1: f32,
}
var<push_constant> g_glass: GlassProps;

struct In {
	@location(0) @interpolate(linear) pos: vec2<f32>,
	@location(1) @interpolate(linear) color: vec4<f32>,
}

struct Out {
	@location(0) color: vec4<f32>,
}

const E = 2.7182818;

fn sd_superellipse(p: vec2<f32>, n: f32, r: f32) -> f32 {
	let p_abs = abs(p);
	let numerator = pow(p_abs.x, n) + pow(p_abs.y, n) - pow(r, n);
	let den_x = pow(p_abs.x, 2.0 * n - 2.0);
	let den_y = pow(p_abs.y, 2.0 * n - 2.0);
	let denominator = n * sqrt(den_x + den_y) + 0.00001;
	return numerator / denominator;
}

fn falloff_curve(x: f32) -> f32 {
	return 1.0 - g_glass.decay_scale * pow(g_glass.base_factor * f32(E), -g_glass.deca_rate * x - g_glass.exponent_offset);
}

fn rand2(co: vec2<f32>) -> f32 {
	return fract(sin(dot(co, vec2(12.71, 31.17))) * 43758.5453);
}

fn glow_from_uv(uv: vec2<f32>) -> f32 {
	let p = uv * 2.0 - vec2(1.0, 1.0);
	return sin(atan2(p.y, p.x) - 0.5);
}

fn glass(uv: vec2<f32>, in_color: vec4<f32>) -> vec4<f32> {
	let center = g_glass.center;
	let scaled_uv = (uv - center) / g_glass.size;
	let p = scaled_uv * 2.0;
	let d = sd_superellipse(p, g_glass.elipse_strength, 1.0);

	let original = vec4(textureSample(g_texture, g_sampler, uv).xyz, 1.0);
    let edge_width = max(fwidth(d), 1e-4);

	if d > 0.0 {
		return original;
	}
	let dist = -d;

    // Edge fade: 1 at center, 0 at the boundary, fading over edge_width
    let edge_alpha: f32 = smoothstep(0.0, edge_width, dist);
	let sample_p = p * pow(falloff_curve(dist), g_glass.refraction_falloff);

    // Map back into UV space
    let coord = sample_p * 0.5 * g_glass.size + center;

	// Out of bounds
	if max(coord.x, coord.y) > 1.0 || min(coord.x, coord.y) < 0.0 {
		return original;
	}

    // Simple UV-based noise
    let noise = vec4(vec3(rand2(scaled_uv * 1e3) - 0.5), 0.0);

	let base = textureSample(g_texture, g_sampler, coord);
	let color = base + noise * g_glass.noise;
	let mul = glow_from_uv(scaled_uv) * g_glass.glow_weight * smoothstep(g_glass.glow_edge0, g_glass.glow_edge1, dist) + 1.0 + g_glass.glow_bias;
	return 
		vec4(color.xyz, 1.0)
		* vec4(vec3(mul), 1.0)
		* vec4(in_color.xyz, 1.0)
		* edge_alpha
		+ original * (1.0 - edge_alpha);
}

@fragment
fn main(in: In) -> Out {
    var out = Out();
    let uv = in.pos;

    out.color = glass(uv, in.color);
    return out;
}
