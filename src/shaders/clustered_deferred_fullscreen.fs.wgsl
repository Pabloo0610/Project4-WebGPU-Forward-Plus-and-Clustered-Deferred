// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.
@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(1) @binding(0) var posTex: texture_2d<f32>;
@group(1) @binding(1) var normTex: texture_2d<f32>;
@group(1) @binding(2) var albedoTex: texture_2d<f32>;
@group(1) @binding(3) var sampler0: sampler;

struct FSIn {
    @builtin(position) fragPos: vec4f
}

const cDim = vec3u(${numClusterX}, ${numClusterY}, ${numClusterZ});
const zNear = ${sceneNear};
const zFar  = ${sceneFar};

@fragment
fn main(in: FSIn) -> @location(0) vec4f {
	//let pos = textureSample(posTex, sampler0, in.uv).xyz;
    let pos = textureLoad(posTex, vec2<u32>(in.fragPos.xy), 0);
	let norm = textureLoad(normTex, vec2<u32>(in.fragPos.xy), 0);
	let albedo = textureLoad(albedoTex, vec2<u32>(in.fragPos.xy), 0);

	// compute cluster indices similar to Forward+
	let ndcPos = camera.viewProjMat * vec4f(pos.xyz, 1.0);
    let viewPos = camera.viewMat * vec4f(pos.xyz, 1.0);
	let ndc = ndcPos.xyz / ndcPos.w;

	let cx = u32(clamp(floor((ndc.x * 0.5 + 0.5) * f32(cDim.x)), 0.0, f32(cDim.x-1u)));
	let cy = u32(clamp(floor((ndc.y * 0.5 + 0.5) * f32(cDim.y)), 0.0, f32(cDim.y-1u)));

	let depthz = clamp(-viewPos.z, zNear, zFar);
	let czF = (depthz - zNear) / (zFar - zNear) * f32(cDim.z);
	let cz = u32(clamp(floor(czF), 0.0, f32(cDim.z - 1u)));

	let clusterIdx = clamp(cz * cDim.x * cDim.y + cy * cDim.x + cx, 0u, cDim.x*cDim.y*cDim.z - 1u);
	let cluster = &clusterSet.clusters[clusterIdx];

	var totalLightContrib = vec3f(0.0, 0.0, 0.0);
	for (var i = 0u; i < (*cluster).numLights; i++) {
		let light = lightSet.lights[(*cluster).lightIndices[i]];
		totalLightContrib += calculateLightContrib(light, pos.xyz, normalize(norm.xyz));
	}

	let finalColor = albedo.rgb * totalLightContrib;
	return vec4f(finalColor, 1.0);
}
