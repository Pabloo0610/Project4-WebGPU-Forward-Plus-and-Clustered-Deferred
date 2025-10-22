// TODO-3: implement the Clustered Deferred fullscreen vertex shader

// This shader should be very simple as it does not need all of the information passed by the the naive vertex shader.
struct VertOut {
	@builtin(position) pos: vec4f,
	@location(0) uv: vec2f
}

@vertex
fn main(@builtin(vertex_index) vi: u32) -> VertOut {
	var out: VertOut;
	// Standard full-screen triangle positions
	let positions = array<vec2f, 3>(vec2f(-1.0, -1.0), vec2f(3.0, -1.0), vec2f(-1.0, 3.0));
	let p = positions[vi];
	out.pos = vec4f(p.x, p.y, 0.0, 1.0);
	// UVs mapped from clip space to [0,1]
	// out.uv = vec2f((p.x * 0.5) + 0.5, (p.y * 0.5) + 0.5);
	return out;
}
