extends CompositorEffect
## Remove only opaque receiver colour, retaining nearer native opaque effects.
## The receiver-only viewport must be a child of the effect viewport, with the
## same camera/size and HDR output. Both cameras currently require MSAA disabled.
const ShaderFile=preload("res://presentation/native_clear_support_colour.glsl")
var receiver_depth: Texture2D
var device: RenderingDevice
var shader: RID
var pipeline: RID
var sampler: RID

func _init() -> void:
    effect_callback_type=EFFECT_CALLBACK_TYPE_POST_OPAQUE
    device=RenderingServer.get_rendering_device()

func _notification(what: int) -> void:
    if what==NOTIFICATION_PREDELETE and shader.is_valid():device.free_rid(shader)
    if what==NOTIFICATION_PREDELETE and sampler.is_valid():device.free_rid(sampler)

func _render_callback(callback_type: int, render_data: RenderData) -> void:
    if callback_type!=EFFECT_CALLBACK_TYPE_POST_OPAQUE or receiver_depth==null:return
    var buffers: RenderSceneBuffersRD=render_data.get_render_scene_buffers()
    if not shader.is_valid():
        # Godot imports this fixed program to SPIR-V before playback. Compiling
        # GLSL inside a spell's first render callback stalls that whole frame.
        var compiled:RDShaderSPIRV=ShaderFile.get_spirv()
        if not compiled.compile_error_compute.is_empty():
            push_error(compiled.compile_error_compute);return
        shader=device.shader_create_from_spirv(compiled)
        pipeline=device.compute_pipeline_create(shader)
        var filtering=RDSamplerState.new()
        filtering.mag_filter=RenderingDevice.SAMPLER_FILTER_NEAREST
        filtering.min_filter=RenderingDevice.SAMPLER_FILTER_NEAREST
        sampler=device.sampler_create(filtering)
    # Only receiver colour changes. Native depth remains available to subsequent
    # transparent hardware tests and Godot's hint_depth_texture copy.
    var size=buffers.get_internal_size()
    var support=RenderingServer.texture_get_rd_texture(receiver_depth.get_rid())
    for view in buffers.get_view_count():
        var uniform=RDUniform.new();uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_IMAGE
        uniform.binding=0;uniform.add_id(buffers.get_color_layer(view))
        var depth_uniform=RDUniform.new();depth_uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
        depth_uniform.binding=1;depth_uniform.add_id(sampler);depth_uniform.add_id(buffers.get_depth_layer(view))
        var support_uniform=RDUniform.new();support_uniform.uniform_type=RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
        support_uniform.binding=2;support_uniform.add_id(sampler);support_uniform.add_id(support)
        var bindings=UniformSetCacheRD.get_cache(shader,0,[uniform,depth_uniform,support_uniform])
        var list=device.compute_list_begin()
        device.compute_list_bind_compute_pipeline(list,pipeline)
        device.compute_list_bind_uniform_set(list,bindings,0)
        device.compute_list_dispatch(list,ceili(float(size.x)/8),ceili(float(size.y)/8),1)
        device.compute_list_end()
