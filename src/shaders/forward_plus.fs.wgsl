// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;


@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f,
    @location(3) pos_view: vec3f
}

const cDim = vec3u(${numClusterX}, ${numClusterY}, ${numClusterZ});
const numClusters = cDim.x * cDim.y * cDim.z;

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var totalLightContrib = vec3f(0, 0, 0);

    let cx = u32(floor(in.fragPos.x / camera.screenSize.x * f32(cDim.x)));
    let cy = u32(floor((1.0-(in.fragPos.y / camera.screenSize.y)) * f32(cDim.y)));

    let zNear = camera.zNearFar.x;
    let zFar  = camera.zNearFar.y;

    let depthz = clamp(-in.pos_view.z, zNear, zFar);
    let czF = (depthz - zNear) / (zFar - zNear) * f32(cDim.z);
    let cz = u32(clamp(floor(czF), 0.0, f32(cDim.z - 1u)));

    let clusterIdx = clamp(cz * cDim.x * cDim.y + cy * cDim.x + cx, 0u, numClusters-1u);
    let cluster = clusterSet.clusters[clusterIdx];

    for (var lightIdx = 0u; lightIdx < cluster.numLights; lightIdx++) {
        let light = lightSet.lights[cluster.lightIndices[lightIdx]];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}