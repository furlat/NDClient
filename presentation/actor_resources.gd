extends RefCounted
## One finite unpublished-world task. Every actor material/mesh here is private;
## selected Texture references are strong snapshots, never live directories.
const Construction=preload("res://presentation/actor_construction.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")
const Placement=preload("res://placement.gd")
const QuadShapes=preload("res://presentation/quad_shapes.gd")

static func build_private(inputs:Dictionary,textures:Dictionary,resources:Dictionary,declared:Dictionary,output:Dictionary)->void:
    var started:int=Time.get_ticks_usec();var rows:Dictionary={};var count:int=0
    for id in inputs:
        var actor:Dictionary=inputs[id];var packets:Dictionary={}
        var condition_parameters:Dictionary=Construction.Conditions.parameters(Construction.Conditions.material(id,[]),textures,resources)
        condition_parameters.make_read_only()
        for index in actor.layers:
            var source:Dictionary=actor.layers[index]
            var layer:Dictionary=source.layer;var row:Dictionary=actor.row;var rig:Dictionary=actor.rig
            var role:String="shadow" if layer.slot=="shadow" else "body"
            var entry:Dictionary={"id":row.id+":"+str(index)+":"+role,"placement":row,"role":role,"layer":index,"source_role":-1,
                "mobile":true,"actor_layer":layer,"source_parameters":declared.duplicate(),"source_changes":{},
                "source_version":1,"source_change_base":1,"source_binding_revision":1}
            var material:=ShaderMaterial.new();material.shader=Construction.MODULAR_SHADER;entry.material=material
            SourceMaterial.set_parameter(entry,"layer_alpha",layer.alpha)
            SourceMaterial.set_parameter(entry,"shadow",layer.slot=="shadow")
            SourceMaterial.apply(entry,actor.light_parameters)
            SourceMaterial.set_parameter(entry,"tint",Construction.Modular.rgb(layer.tint))
            var shape:Dictionary=Construction.layer_shape(rig,actor.scale)
            var mesh:=QuadShapes.mesh(shape.mesh_size,shape.mesh_center)
            material.set_shader_parameter("source_quad_size",shape.mesh_size)
            entry.cell=shape.cell;entry.pivot=shape.pivot;entry.scale=shape.scale
            var origin:Vector2=Placement.project(Vector2(row.position[0],row.position[1]),row.base_height_steps,actor.quarter)
            entry.screen_rect=Rect2(origin-entry.pivot*entry.scale,entry.cell*entry.scale)
            SourceMaterial.apply(entry,condition_parameters);entry.bound_condition_parameters=condition_parameters
            var ready:Dictionary=Construction.realize_private_binding(source.binding,textures)
            entry.prepared_source_binding=ready
            Construction.bind_source_values(entry,rig,source.binding.path,source.frame,actor.facing,ready.sheet,ready.sheet_size,textures,resources,condition_parameters)
            Construction.CharacterGeometry.apply_binding_values(entry,ready.geometry)
            var bounds:AABB=Construction.CharacterGeometry.binding_bounds(mesh.get_aabb(),ready.geometry.bounds)
            var pending:Dictionary={}
            if ready.sheet==null:pending.sheet=source.binding.path
            for parameter in ready.geometry.textures:
                var path:String=ready.geometry.textures[parameter]
                if textures.get(path)==null:pending[parameter]=path
            var palette:Dictionary=layer.get("effect",{}).get("palette",{}) if layer.get("effect",{}).get("palette")!=null else {}
            var noise:String=resources.get(palette.get("noiseSheet"),"")
            if not noise.is_empty() and textures.get(noise)==null:pending.effect_noise=noise
            material.get_rid()
            # The finished layer node, outside any tree: the scene owner only attaches it.
            var node:=MeshInstance3D.new()
            node.mesh=mesh;node.material_override=material
            node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            node.sorting_use_aabb_center=false;node.custom_aabb=bounds
            entry.node=node
            var packet:Dictionary={"entry":entry,"mesh":mesh,"aabb":bounds,"pending_textures":pending,"noise_path":noise,"condition_parameters":condition_parameters}
            packets[index]=packet;count+=1
        rows[id]=packets
    output.merge({"complete":true,"error":"","rows":rows,"draw_count":count,"worker_ms":(Time.get_ticks_usec()-started)/1000.0})
