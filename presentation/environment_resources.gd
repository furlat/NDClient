extends RefCounted
## One finite world-owned task. All resources created here are private until
## the scene owner adopts them; referenced textures are captured strong refs.
const SHADER=preload("res://environment.gdshader")
const SourceMaterial=preload("res://presentation/source_material.gd")
const QuadShapes=preload("res://presentation/quad_shapes.gd")

static func build_private(packets:Dictionary,texture_refs:Dictionary,declared_names:Dictionary,output:Dictionary)->void:
    var started:int=Time.get_ticks_usec();var rows:Dictionary={};var count:int=0
    # The joined owner must retain every allocated node, including a partial
    # row when a later source fails. Consumers only read this after join().
    output.rows=rows
    for id in packets:
        var entries:Array=[]
        rows[id]=entries
        for selected in packets[id].entries:
            var descriptor:Dictionary=selected.descriptor
            var entry:Dictionary=selected.duplicate();entry.erase("descriptor")
            var material:=ShaderMaterial.new();material.shader=SHADER
            var parameters:Dictionary=declared_names.duplicate();var changes:Dictionary={};var version:int=2
            if not descriptor.get("empty",false):
                parameters.door_leaf_partition=0;changes.door_leaf_partition=0;version+=1
                material.set_shader_parameter("door_leaf_partition",0)
                for name in descriptor.parameters:
                    var value:Variant=descriptor.parameters[name]
                    if parameters.get(name)!=value:
                        parameters[name]=value;changes[name]=value;version+=1;material.set_shader_parameter(name,value)
                for name in descriptor.texture_parameters:
                    var path:String=descriptor.texture_parameters[name]
                    if not texture_refs.has(path):
                        output.merge({"complete":false,"error":"Missing prepared environment texture: "+path,"worker_ms":(Time.get_ticks_usec()-started)/1000.0});return
                    var value:Texture2D=texture_refs[path]
                    parameters[name]=value;changes[name]=value;version+=1;material.set_shader_parameter(name,value)
            var mesh:=QuadShapes.mesh(Vector2.ONE)
            if not descriptor.get("empty",false):
                mesh=QuadShapes.mesh(descriptor.mesh_size,descriptor.mesh_center)
                material.set_shader_parameter("source_quad_size",descriptor.mesh_size)
            entry.merge({"material":material,"mesh":mesh,"prepared_source":descriptor,"source_parameters":parameters,
                "source_changes":changes,"source_version":version,"source_change_base":1,"source_binding_revision":2})
            # These are the same final scene policy operands. They belong to
            # this source constructor, before its first sample.
            SourceMaterial.apply(entry,selected.get("light_parameters",{}))
            material.get_rid()
            # The finished sprite node, outside any tree: the scene owner only attaches it.
            var node:=MeshInstance3D.new()
            entry.node=node;entries.append(entry)
            node.mesh=mesh;node.material_override=material
            node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            node.sorting_use_aabb_center=false
            node.position=descriptor.position;node.basis=descriptor.basis;node.visible=descriptor.visible
            if not descriptor.get("empty",false):node.custom_aabb=descriptor.aabb
            count+=1
    output.merge({"complete":true,"error":"","rows":rows,"worker_ms":(Time.get_ticks_usec()-started)/1000.0,"draw_count":count})
