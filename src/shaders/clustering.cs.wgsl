// TODO-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

@group(${bindGroup_scene}) @binding(0) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(1) var<storage, read_write> clusterSet: ClusterSet;

@group(${bindGroup_scene}) @binding(2) var<uniform> camera: CameraUniforms;

const cDim = vec3u(${numClusterX}, ${numClusterY}, ${numClusterZ});
const numClusters = cDim.x * cDim.y * cDim.z;

fn zlinearSliceNdc(near: f32, far: f32, totalz: f32, curz: f32) ->vec2f {
    let dn: f32 = -mix(near, far, curz / totalz);
    let df: f32 = -mix(near, far, (curz+ 1.0) / totalz);
    // convert view to ndc
    let viewn = vec4f(0.0,0.0,dn,1.0);
    let viewf = vec4f(0.0,0.0,df,1.0);

    let clipn = camera.projMat * viewn;
    let ndcn = clipn.z / clipn.w;
    let clipf = camera.projMat * viewf;
    let ndcf = clipf.z / clipf.w;

    return vec2f(ndcn, ndcf);
}

fn zlogSliceNdc(near: f32, far: f32, totalz: f32, curz: f32) -> vec2f {
    let logNear = log(near);
    let logFar = log(far);

    let t0 = curz / totalz;
    let t1 = (curz + 1.0) / totalz;

    let zNearSlice = exp(mix(logNear, logFar, t0));
    let zFarSlice = exp(mix(logNear, logFar, t1));

    let dn = -zNearSlice;
    let df = -zFarSlice;

    let viewn = vec4f(0.0, 0.0, dn, 1.0);
    let viewf = vec4f(0.0, 0.0, df, 1.0);

    let clipn = camera.projMat * viewn;
    let ndcn = clipn.z / clipn.w;
    let clipf = camera.projMat * viewf;
    let ndcf = clipf.z / clipf.w;

    return vec2f(ndcn, ndcf);
}

fn sphereAABBIntersectionTest(c:vec3f, r:f32, bmin:vec3f, bmax:vec3f) -> bool {
    let nearest = clamp(c, bmin, bmax);

    let dist2 = dot(c-nearest, c-nearest);
    if (dist2 < r*r) {
        return true;
    } else {
        return false;
    }
}

@compute
@workgroup_size(${clusterLightsWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let clusterIdx = globalIdx.x; // idx = x + y*dimX + z*dimX*dimY;
    if (clusterIdx >= numClusters) {
        return;
    }
    let cz = clusterIdx / (cDim.x*cDim.y);
    let cy = (clusterIdx-cz*cDim.x*cDim.y) / cDim.x;
    let cx = clusterIdx-cz*cDim.x*cDim.y-cy*cDim.x;

    // let ndcx0 = (f32(cx) / f32(cDim.x)) * 2.0 - 1.0;
    // let ndcx1 = (f32(cx+1u) / f32(cDim.x)) * 2.0 - 1.0;
    // let ndcy0 = (f32(cy) / f32(cDim.y)) * 2.0 - 1.0;
    // let ndcy1 = (f32(cy+1u) / f32(cDim.y)) * 2.0 - 1.0;
    let ndcx = vec2f((f32(cx) / f32(cDim.x)) * 2.0 - 1.0, (f32(cx+1u) / f32(cDim.x)) * 2.0 - 1.0);
    let ndcy = vec2f((f32(cy) / f32(cDim.y)) * 2.0 - 1.0, (f32(cy+1u) / f32(cDim.y)) * 2.0 - 1.0);

    let ndcz = zlinearSliceNdc(${sceneNear}, ${sceneFar}, f32(cDim.z), f32(cz));
    //let ndcz = zlogSliceNdc(camera.zNearFar.x, camera.zNearFar.y, f32(cDim.z), f32(cz));
    // let ndcz0 = ndcz.x;
    // let ndcz1 = ndcz.y;
    var bmin = vec3f( 1e30,  1e30,  1e30);
    var bmax = vec3f(-1e30, -1e30, -1e30);

    for(var i=0u; i<2u;i++) {
        for(var j=0u; j<2u;j++) {
            for(var k=0u; k<2u;k++) {
                let curNdcCorner = vec4f(ndcx[i],ndcy[j],ndcz[k],1.0);
                let curViewCornerRaw = camera.invProjMat * curNdcCorner;
                let curViewCorner = curViewCornerRaw.xyz / curViewCornerRaw.w;

                bmin = min(bmin, curViewCorner);
                bmax = max(bmax, curViewCorner);
            }
        }
    } 

    let bbox = AABB(bmin, bmax);
    var curNLights = 0u;
    var lightIndices = array<u32, ${numLightsPerCluster}u>();

    let lightRadius = f32(${lightRadius});
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        if (curNLights >= ${numLightsPerCluster}) {
            break;
        }
        let lightPosWorld = lightSet.lights[lightIdx].pos;
        let lightPosView = (camera.viewMat * vec4f(lightPosWorld, 1.0)).xyz;

        if(sphereAABBIntersectionTest(lightPosView, lightRadius, bbox.min, bbox.max)) {
            lightIndices[curNLights] = lightIdx;
            curNLights += 1u;
        }
    }

    let cluster = Cluster(bbox, curNLights, lightIndices);
    clusterSet.clusters[clusterIdx] = cluster;
}