struct In {
	@builtin(vertex_index) vertex_index: u32,
}

struct Out {
	@builtin(position) position: vec4<f32>,
#ifdef TW_TEXTURED
	@location(0) @interpolate(linear) tex: vec3<f32>,
#endif
}

struct PosBO {
	pos: mat4x2<f32>,
	pos_y: f32,
	alignment: f32,
}
var<push_constant> g_pos: PosBO;

struct Tile {
	posx_tex3d: u32,
}
@group(2) @binding(0) 
var<storage, read> g_tiles: array<Tile>;

@vertex
fn main(in: In) -> Out {
	var out = Out();

	let index = u32(in.vertex_index / 4u);
	let vertex = u32(in.vertex_index % 4u);
	let off_x = select(0.0, 1.0, vertex == 1 || vertex == 2);
	let off_y = select(0.0, 1.0, vertex == 3 || vertex == 2);
	let tile = g_tiles[index];
	let pos_x = u32(tile.posx_tex3d & 0xFFFFu);
	out.position = vec4(g_pos.pos * vec4(vec2<f32>(f32(pos_x) + off_x, g_pos.pos_y + off_y), 0.0, 1.0), 0.0, 1.0);

#ifdef TW_TEXTURED
	let tex3d = u32(tile.posx_tex3d >> 16u);
	let x = (tex3d >> (vertex * 2u)) & 1u;
	let y = (tex3d >> (vertex * 2u + 1u)) & 1u;
	let tex_index = (tex3d >> 8u) & 255u;
	out.tex = vec3<f32>(f32(x), f32(y), f32(tex_index));
#endif
	return out;
}
