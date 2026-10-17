extends RefCounted
## One finite world-owned task. All resources created here are private until
## the scene owner adopts them; referenced textures are captured strong refs.
const SHADER=preload("res://environment.gdshader")
const Atlas=preload("res://presentation/native_light_atlas.gd")
const SourceMaterial=preload("res://presentation/source_material.gd")

static func build_private(packets:Dictionary,texture_refs:Dictionary,declared_names:Dictionary,output:Dictionary,image_refs:Dictionary={},atlas_options:Dictionary={})->void:
    var started:int=Time.get_ticks_usec();var rows:Dictionary={};var count:int=0;var crops:Dictionary={};var crop_usec:int=0;var binding_usec:int=0
    for id in packets:
        var entries:Array=[]
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
            var mesh:=QuadMesh.new()
            if not descriptor.get("empty",false):
                mesh.size=descriptor.mesh_size;mesh.center_offset=descriptor.mesh_center
                material.set_shader_parameter("source_quad_size",descriptor.mesh_size)
            mesh.get_rid()
            entry.merge({"material":material,"mesh":mesh,"prepared_source":descriptor,"source_parameters":parameters,
                "source_changes":changes,"source_version":version,"source_change_base":1,"source_binding_revision":2})
            # These are the same final scene policy operands. They belong to
            # this source constructor, before its atlas materials and sample.
            SourceMaterial.apply(entry,selected.get("light_parameters",{}))
            material.get_rid()
            if not atlas_options.is_empty() and not descriptor.get("empty",false):
                var crop_started:int=Time.get_ticks_usec()
                var path:String=descriptor.record.path
                if not image_refs.has(path):
                    output.merge({"complete":false,"error":"Missing prepared environment image: "+path});return
                var image:Image=image_refs[path]
                var cell:=Vector2i(descriptor.cell);var r:Array=descriptor.record.get("rect",[0,0,cell.x,cell.y])
                var region:=Rect2i(int(r[0]),int(r[1]),int(r[2]),int(r[3]))
                var key:Array=[image.get_instance_id(),region,cell]
                if not crops.has(key):
                    crops[key]=atlas_options.get("cached_crops",{}).get(key,{})
                    if crops[key].is_empty():
                        if not Rect2i(Vector2i.ZERO,image.get_size()).encloses(region) or not region.has_area() or cell.x<1 or cell.y<1:
                            output.merge({"complete":false,"error":"Environment original region is outside its prepared image: "+path});return
                        crops[key]=Atlas.static_crop(image,region,cell)
                crop_usec+=Time.get_ticks_usec()-crop_started
                var binding_started:int=Time.get_ticks_usec()
                entry.static_atlas_packet=Atlas.private_environment_binding(entry,descriptor,atlas_options,crops[key],key)
                binding_usec+=Time.get_ticks_usec()-binding_started
            entries.append(entry);count+=1
        rows[id]=entries
    output.merge({"complete":true,"error":"","rows":rows,"worker_ms":(Time.get_ticks_usec()-started)/1000.0,"draw_count":count,"crop_worker_ms":crop_usec/1000.0,"binding_worker_ms":binding_usec/1000.0,"unique_crops":crops.size()})
