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
}
var<push_constant> g_pos: PosBO;

struct Tile {
	pos: u32,
#ifdef TW_TEXTURED
	tex3d: u32,
#endif
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
	let pos_x = u32(tile.pos & 0xFFFFu);
	let pos_y = u32(tile.pos >> 16u);
	out.position = vec4(g_pos.pos * vec4(vec2<f32>(f32(pos_x) + off_x, f32(pos_y) + off_y), 0.0, 1.0), 0.0, 1.0);

#ifdef TW_TEXTURED
	var x = (tile.tex3d >> (vertex * 2)) & 1;
	var y = (tile.tex3d >> (vertex * 2 + 1)) & 1;
	var tex_index = (tile.tex3d >> 8u) & 255;
	out.tex = vec3<f32>(f32(x), f32(y), f32(tex_index));
#endif
	return out;
}
