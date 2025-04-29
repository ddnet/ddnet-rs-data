struct In {
	@builtin(vertex_index) vertex_index: u32,
}

struct Out {
	@builtin(position) position: vec4<f32>,
	@location(0) @interpolate(linear, centroid) pos: vec2<f32>,
}

struct PosBO {
	pos: mat4x2<f32>,
	offset: vec2<f32>,
	scale: vec2<f32>,
}
var<push_constant> g_pos: PosBO;

@vertex
fn main(in: In) -> Out {
	var out = Out();

	let vertex = u32(in.vertex_index % 6u);
	let off_x = select(0.0, 1.0, vertex == 1 || vertex == 2 || vertex == 4);
	let off_y = select(0.0, 1.0, vertex == 5 || vertex == 2 || vertex == 4);
	let pos = vec2<f32>(
		off_x * g_pos.scale.x + g_pos.offset.x,
		off_y * g_pos.scale.y + g_pos.offset.y
	);
	out.position = vec4(g_pos.pos * vec4(pos, 0.0, 1.0), 0.0, 1.0);
	out.pos = pos;

	return out;
}
