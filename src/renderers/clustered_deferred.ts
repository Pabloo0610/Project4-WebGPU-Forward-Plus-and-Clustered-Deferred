import * as renderer from '../renderer';
import * as shaders from '../shaders/shaders';
import { Stage } from '../stage/stage';

export class ClusteredDeferredRenderer extends renderer.Renderer {
    // TODO-3: add layouts, pipelines, textures, etc. needed for Forward+ here
    // you may need extra uniforms such as the camera view matrix and the canvas resolution

    sceneUniformsBindGroupLayout: GPUBindGroupLayout;
    sceneUniformsBindGroup: GPUBindGroup;

    posTexture: GPUTexture;
    posTextureView: GPUTextureView;
    normTexture: GPUTexture;
    normTextureView: GPUTextureView;
    albedoTexture: GPUTexture;
    albedoTextureView: GPUTextureView;
    depthTexture: GPUTexture;
    depthTextureView: GPUTextureView;

    gbuffersBindGroupLayout: GPUBindGroupLayout;
    gbuffersBindGroup: GPUBindGroup;

    gbufferPipeline: GPURenderPipeline;
    fullscreenPipeline: GPURenderPipeline;

    constructor(stage: Stage) {
        super(stage);

        // TODO-3: initialize layouts, pipelines, textures, etc. needed for Forward+ here
        // you'll need two pipelines: one for the G-buffer pass and one for the fullscreen pass
        this.sceneUniformsBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "scene uniforms bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: { type: "uniform" }
                },
                { // lightSet
                    binding: 1,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                },
                { // clusterSet
                    binding: 2,
                    visibility: GPUShaderStage.FRAGMENT,
                    buffer: { type: "read-only-storage" }
                }
            ]
        });

        this.sceneUniformsBindGroup = renderer.device.createBindGroup({
            label: "scene uniforms bind group",
            layout: this.sceneUniformsBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: { buffer: this.camera.uniformsBuffer}
                },
                {
                    binding: 1,
                    resource: { buffer: this.lights.lightSetStorageBuffer }
                },
                {
                    binding: 2,
                    resource: { buffer: this.lights.clusterSetStorageBuffer }
                }
            ]
        });

        const size: [number, number] = [renderer.canvas.width, renderer.canvas.height];

        this.posTexture = renderer.device.createTexture({
            size: size,
            format: "rgba32float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.posTextureView = this.posTexture.createView();

        this.normTexture = renderer.device.createTexture({
            size: size,
            format: "rgba16float",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.normTextureView = this.normTexture.createView();

        this.albedoTexture = renderer.device.createTexture({
            size: size,
            format: "rgba8unorm",
            usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING
        });
        this.albedoTextureView = this.albedoTexture.createView();

        this.depthTexture = renderer.device.createTexture({
            size: size,
            format: "depth24plus",
            usage: GPUTextureUsage.RENDER_ATTACHMENT
        });
        this.depthTextureView = this.depthTexture.createView();

        // Bind group for sampling G-buffer
        this.gbuffersBindGroupLayout = renderer.device.createBindGroupLayout({
            label: "gbuffers bind group layout",
            entries: [
                { binding: 0, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: 'unfilterable-float' } }, // pos
                { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: 'unfilterable-float' } }, // norm
                { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: { sampleType: 'float' } }, // albedo (unorm)
                { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: { type: 'non-filtering' } }
            ]
        });

        // Use a non-filtering sampler (nearest) because some G-buffer textures are unfilterable float formats
        const gbSampler = renderer.device.createSampler({
            magFilter: 'nearest',
            minFilter: 'nearest',
            mipmapFilter: 'nearest'
        });

        this.gbuffersBindGroup = renderer.device.createBindGroup({
            label: "gbuffers bind group",
            layout: this.gbuffersBindGroupLayout,
            entries: [
                { binding: 0, resource: this.posTextureView },
                { binding: 1, resource: this.normTextureView },
                { binding: 2, resource: this.albedoTextureView },
                { binding: 3, resource: gbSampler }
            ]
        });

        // G-buffer pipeline
        this.gbufferPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "gbuffer pipeline layout",
                bindGroupLayouts: [ this.sceneUniformsBindGroupLayout, renderer.modelBindGroupLayout, renderer.materialBindGroupLayout ]
            }),
            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth24plus"
            },
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "gbuffer vert shader",
                    code: shaders.naiveVertSrc
                }),
                buffers: [ renderer.vertexBufferLayout ]
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "gbuffer frag shader",
                    code: shaders.clusteredDeferredFragSrc
                }),
                targets: [
                    { format: "rgba32float" },
                    { format: "rgba16float" },
                    { format: "rgba8unorm" }
                ]
            }
        });

        // Fullscreen pipeline
        this.fullscreenPipeline = renderer.device.createRenderPipeline({
            layout: renderer.device.createPipelineLayout({
                label: "fullscreen pipeline layout",
                // fullscreen pass doesn't use model bind groups, so only include scene and gbuffers
                bindGroupLayouts: [ this.sceneUniformsBindGroupLayout, this.gbuffersBindGroupLayout ]
            }),
            vertex: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred fullscreen vert",
                    code: shaders.clusteredDeferredFullscreenVertSrc
                }),
                entryPoint: "main",
                buffers: []
            },
            fragment: {
                module: renderer.device.createShaderModule({
                    label: "clustered deferred fullscreen frag",
                    code: shaders.clusteredDeferredFullscreenFragSrc
                }),
                targets: [ { format: renderer.canvasFormat } ]
            }
        });
    }

    override draw() {
        // TODO-3: run the Forward+ rendering pass:
        // - run the clustering compute shader
        // - run the G-buffer pass, outputting position, albedo, and normals
        // - run the fullscreen pass, which reads from the G-buffer and performs lighting calculations
        const encoder = renderer.device.createCommandEncoder();
        const canvasTextureView = renderer.context.getCurrentTexture().createView();

        // 1) Run clustering compute shader
        this.lights.doLightClustering(encoder);

        // 2) G-buffer pass
        const gbufferPass = encoder.beginRenderPass({
            label: "gbuffer pass",
            colorAttachments: [
                {
                    view: this.posTextureView,
                    loadOp: "clear",
                    clearValue: [0,0,0,0],
                    storeOp: "store"
                },
                {
                    view: this.normTextureView,
                    loadOp: "clear",
                    clearValue: [0,0,0,0],
                    storeOp: "store"
                },
                {
                    view: this.albedoTextureView,
                    loadOp: "clear",
                    clearValue: [0,0,0,0],
                    storeOp: "store"
                }
            ],
            depthStencilAttachment: {
                view: this.depthTextureView,
                depthClearValue: 1.0,
                depthLoadOp: "clear",
                depthStoreOp: "store"
            }
        });

        gbufferPass.setPipeline(this.gbufferPipeline);
        gbufferPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);

        this.scene.iterate(node => {
            gbufferPass.setBindGroup(shaders.constants.bindGroup_model, node.modelBindGroup);
        }, material => {
            gbufferPass.setBindGroup(shaders.constants.bindGroup_material, material.materialBindGroup);
        }, primitive => {
            gbufferPass.setVertexBuffer(0, primitive.vertexBuffer);
            gbufferPass.setIndexBuffer(primitive.indexBuffer, 'uint32');
            gbufferPass.drawIndexed(primitive.numIndices);
        });

        gbufferPass.end();

        // 3) Fullscreen pass: read G-buffer, apply lighting using clusters
        const fsPass = encoder.beginRenderPass({
            label: "clustered deferred fullscreen pass",
            colorAttachments: [
                {
                    view: canvasTextureView,
                    loadOp: "clear",
                    clearValue: [0,0,0,0],
                    storeOp: "store"
                }
            ]
        });

        fsPass.setPipeline(this.fullscreenPipeline);
        fsPass.setBindGroup(shaders.constants.bindGroup_scene, this.sceneUniformsBindGroup);
        // bind G-buffer textures at group index 1 (fullscreen pipeline expects scene at 0, gbuffers at 1)
        fsPass.setBindGroup(1, this.gbuffersBindGroup);

        // Draw a fullscreen triangle — no vertex buffers needed if the VS creates positions.
        fsPass.draw(3);
        fsPass.end();

        renderer.device.queue.submit([encoder.finish()]);
    }
}

