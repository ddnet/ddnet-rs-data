
struct In {
	@location(0) @interpolate(linear, centroid) pos: vec2<f32>,
}

struct Out {
	@location(0) color: vec4<f32>,
}

struct Tile {
	posx_tex3d: u32,
}
@group(2) @binding(0) 
var<storage, read> g_tiles: array<Tile>;

@group(0) @binding(0) var g_texture: texture_2d_array<f32>;
@group(1) @binding(0) var g_sampler: sampler;

struct Frag {
	padding: array<f32, 16>,
	color: vec4<f32>,
	layer_size: vec2<u32>,
}
var<push_constant> g_frag: Frag;

/**
* The idea
* | name      | (i00,i10,i11,i01)  | formula for T(u,v)=(u',v')      |
* |:---------:|:------------------:|:-------------------------------:|
* | identity  | (0,1,2,3)          | u'=u,v'=v                       |
* | rot 90    | (1,2,3,0)          | u'=1-v,v'=u                     |
* | rot 180   | (2,3,0,1)          | u'=1-u,v'=1-v                   |
* | rot 270   | (3,0,1,2)          | u'=v,v'=1-u                     |
* | mirror X  | (1,0,3,2)          | u'=1-u,v'=v                     |
* | mirror Y  | (3,2,1,0)          | u'=u,v'=1-v                     |
* | mirror d₁ | (0,3,2,1)          | u'=v,v'=u                       |
* | mirror d₂ | (2,1,0,3)          | u'=1-v,v'=1-u                   |
**/
fn map_into_quad_space(u: f32, v: f32, corners: array<vec2<u32>, 4>) -> vec2<f32> {
	var i00: u32 = 0xffffffffu;
	var i10: u32 = 0xffffffffu;
	var i11: u32 = 0xffffffffu;
	var i01: u32 = 0xffffffffu;

	// Calc which corner is which
	 // corner 0
    let x0 = corners[0].x;
    let y0 = corners[0].y;
    if (x0 == 0u && y0 == 0u) {
        i00 = 0u;
    } else if (x0 == 1u && y0 == 0u) {
        i10 = 0u;
    } else if (x0 == 1u && y0 == 1u) {
        i11 = 0u;
    } else if (x0 == 0u && y0 == 1u) {
        i01 = 0u;
    }
    // corner 1
    let x1 = corners[1].x;
    let y1 = corners[1].y;
    if (x1 == 0u && y1 == 0u) {
        i00 = 1u;
    } else if (x1 == 1u && y1 == 0u) {
        i10 = 1u;
    } else if (x1 == 1u && y1 == 1u) {
        i11 = 1u;
    } else if (x1 == 0u && y1 == 1u) {
        i01 = 1u;
    }
    // corner 2
    let x2 = corners[2].x;
    let y2 = corners[2].y;
    if (x2 == 0u && y2 == 0u) {
        i00 = 2u;
    } else if (x2 == 1u && y2 == 0u) {
        i10 = 2u;
    } else if (x2 == 1u && y2 == 1u) {
        i11 = 2u;
    } else if (x2 == 0u && y2 == 1u) {
        i01 = 2u;
    }
    // corner 3
    let x3 = corners[3].x;
    let y3 = corners[3].y;
    if (x3 == 0u && y3 == 0u) {
        i00 = 3u;
    } else if (x3 == 1u && y3 == 0u) {
        i10 = 3u;
    } else if (x3 == 1u && y3 == 1u) {
        i11 = 3u;
    } else if (x3 == 0u && y3 == 1u) {
        i01 = 3u;
    }

	// Assign res here as fallback, this fallback should never be used
	// but cannot panic inside a shader
	var res = vec2<f32>(u, v);

	// Match the configuration and return the transformed (u, v)
    if        (i00 == 0u && i10 == 1u && i11 == 2u && i01 == 3u) {
        // identity
        res = vec2<f32>( u,        v       );
    } else if (i00 == 1u && i10 == 2u && i11 == 3u && i01 == 0u) {
        //  90° clockwise
        res = vec2<f32>( v,        1.0 - u );
    } else if (i00 == 2u && i10 == 3u && i11 == 0u && i01 == 1u) {
        // 180°
        res = vec2<f32>( 1.0 - u,  1.0 - v );
    } else if (i00 == 3u && i10 == 0u && i11 == 1u && i01 == 2u) {
        // 270° clockwise
        res = vec2<f32>( 1.0 - v,  u       );
    } else if (i00 == 1u && i10 == 0u && i11 == 3u && i01 == 2u) {
        // mirror X
        res = vec2<f32>( 1.0 - u,  v       );
    } else if (i00 == 3u && i10 == 2u && i11 == 1u && i01 == 0u) {
        // mirror Y
        res = vec2<f32>( u,        1.0 - v );
    } else if (i00 == 0u && i10 == 3u && i11 == 2u && i01 == 1u) {
        // mirror diag y=x
        res = vec2<f32>( v,        u       );
    } else if (i00 == 2u && i10 == 1u && i11 == 0u && i01 == 3u) {
        // mirror diag y=1−x
        res = vec2<f32>( 1.0 - v,  1.0 - u );
    }

	return res;
}


@fragment
fn main(
	in: In
) -> Out {
	var out = Out();

	let x = clamp(u32(in.pos.x), 0u, g_frag.layer_size.x - 1);
	let y = clamp(u32(in.pos.y), 0u, g_frag.layer_size.y - 1);

	let index = y * g_frag.layer_size.x + x;
	let tile = g_tiles[index];
	let tex3d = u32(tile.posx_tex3d >> 16u);
	let tex_index = (tex3d >> 8u) & 255u;

	let x0 = (tex3d >> 0u) & 1u;
	let y0 = (tex3d >> 1u) & 1u;
	let x1 = (tex3d >> 2u) & 1u;
	let y1 = (tex3d >> 3u) & 1u;
	let x2 = (tex3d >> 4u) & 1u;
	let y2 = (tex3d >> 5u) & 1u;
	let x3 = (tex3d >> 6u) & 1u;
	let y3 = (tex3d >> 7u) & 1u;

	let real_tex = fract(in.pos);
	let dx = dpdx(in.pos);
	let dy = dpdy(in.pos);

	let corners = array<vec2<u32>, 4>(
		vec2<u32>(x0, y0),
		vec2<u32>(x1, y1),
		vec2<u32>(x2, y2),
		vec2<u32>(x3, y3),
	);
	let tex_coords = map_into_quad_space(
		real_tex.x,
		real_tex.y,
		corners,
	);

	let tex_color = textureSampleGrad(g_texture, g_sampler, tex_coords, tex_index, dx, dy);

	out.color = tex_color * g_frag.color;

	return out;
}
