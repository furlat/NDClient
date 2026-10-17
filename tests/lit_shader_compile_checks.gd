extends SceneTree
# Every lit sprite shader compiles and renders one frame without errors.
const SHADERS = ["res://environment.gdshader", "res://modular.gdshader", "res://water.gdshader", "res://presentation/fixture_flame.gdshader"]

func _initialize() -> void: run.call_deferred()

func run() -> void:
    var view := SubViewport.new(); view.size = Vector2i(64, 64); view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(view)
    var camera := Camera3D.new(); camera.projection = Camera3D.PROJECTION_ORTHOGONAL; camera.size = 4.0; camera.position = Vector3(0, 0, 5)
    view.add_child(camera)
    var failures := []
    for path in SHADERS:
        var shader: Shader = load(path)
        if shader == null: failures.append(path); continue
        var node := MeshInstance3D.new(); node.mesh = QuadMesh.new()
        var material := ShaderMaterial.new(); material.shader = shader; node.material_override = material
        view.add_child(node)
        print("LIT_SHADER uniforms ", path, " ", shader.get_shader_uniform_list().size())
    for i in 3: await process_frame
    await RenderingServer.frame_post_draw
    print("LIT_SHADER_DONE ", failures)
    quit(0 if failures.is_empty() else 1)
