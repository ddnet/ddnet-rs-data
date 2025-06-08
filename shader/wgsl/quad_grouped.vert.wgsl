struct In {
	@location(0) pos: vec4<f32>,
	@location(1) color: vec4<f32>,
#ifdef TW_TEXTURED
	@location(2) tex: vec2<f32>,
#endif
}

struct Out {
	@builtin(position) position: vec4<f32>,
	@location(0) @interpolate(linear) color: vec4<f32>,
#ifdef TW_TEXTURED
	@location(1) @interpolate(linear) tex: vec2<f32>,
#endif
}

struct ProjectionMat {
	pos: mat4x2<f32>,

	color: vec4<f32>,
	offset: vec2<f32>,
	rotation: f32,
}
var<push_constant> g_proj: ProjectionMat;

@vertex
fn main(in: In) -> Out
{
	var out = Out();

	var final_pos = in.pos.xy;
	if g_proj.rotation != 0.0 {
		var x = final_pos.x - in.pos.z;
		var y = final_pos.y - in.pos.w;
		
		final_pos.x = x * cos(g_proj.rotation) - y * sin(g_proj.rotation) + in.pos.z;
		final_pos.y = x * sin(g_proj.rotation) + y * cos(g_proj.rotation) + in.pos.w;
	}

	final_pos.x = final_pos.x + g_proj.offset.x;
	final_pos.y = final_pos.y + g_proj.offset.y;

	out.position = vec4(g_proj.pos * vec4(final_pos, 0.0, 1.0), 0.0, 1.0);
	out.color = in.color * g_proj.color;
#ifdef TW_TEXTURED
	out.tex = in.tex;
#endif
	return out;
}
