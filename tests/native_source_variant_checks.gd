extends SceneTree
## Exact original source state and private prepared instances on real Gallery
## sources. Native raster qualification is reported independently from CPU time.
const Recording=preload("res://studio/recording.gd")
const Before=preload("res://presentation/native_factory_source.gd")
const After=preload("res://presentation/native_factory_source.gd")
const Variants=preload("res://presentation/native_source_variants.gd")
var checks:int=0
var failures:Array=[]
var rows:Array=[]
var transform_roundoff:Array=[]
var before_root:Node
var after_root:Node
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label)
func effective(resource:Resource,field:String)->Variant:
    var value:Variant=resource.get(field)
    if value==null and resource is ShaderMaterial and field.begins_with("shader_parameter/"):
        var name:StringName=StringName(field.trim_prefix("shader_parameter/"))
        var texture:Texture2D=resource.shader.get_default_texture_parameter(name)
        return texture if texture!=null else RenderingServer.shader_get_parameter_default(resource.shader.get_rid(),name)
    return value
func compare(a:Variant,b:Variant,path:String,seen:Dictionary)->void:
    checks+=1
    if a is Resource and b is Resource:
        var pair:String=str(a.get_instance_id())+":"+str(b.get_instance_id())
        if seen.has(pair):return
        seen[pair]=true
        if a is Shader and b is Shader:
            if a.code!=b.code:failures.append(path+": shader code differs")
            return
        if a.get_class()!=b.get_class():failures.append(path+": resource class differs");return
        if a is CompressedTexture2D and b is CompressedTexture2D:
            # Textures are immutable selected dependencies, never reauthored.
            if a.resource_path!=b.resource_path and a.get_image().get_data()!=b.get_image().get_data():failures.append(path+": texture pixels differ")
            return
        for field in a.get_property_list():
            if not int(field.usage)&PROPERTY_USAGE_STORAGE or str(field.name) in ["resource_name","resource_path","resource_local_to_scene"]:continue
            compare(effective(a,field.name),effective(b,field.name),path+"/"+str(field.name),seen)
    elif a is Array and b is Array:
        if a.size()!=b.size():failures.append(path+": array size");return
        for i in a.size():compare(a[i],b[i],path+"/"+str(i),seen)
    elif a is Dictionary and b is Dictionary:
        if a.size()!=b.size():failures.append(path+": dictionary size");return
        for key in a:
            if not b.has(key):failures.append(path+": missing key "+str(key));continue
            compare(a[key],b[key],path+"/"+str(key),seen)
    elif a is Node and b is Node:
        if before_root.get_path_to(a)!=after_root.get_path_to(b):failures.append(path+": node-relative reference differs")
    elif a is Transform3D and b is Transform3D and a!=b:
        var maximum:float=0.0
        for axis in 4:
            var av:Vector3=a.basis[axis] if axis<3 else a.origin
            var bv:Vector3=b.basis[axis] if axis<3 else b.origin
            maximum=maxf(maximum,maxf(absf(av.x-bv.x),maxf(absf(av.y-bv.y),absf(av.z-bv.z))))
        transform_roundoff.append({"path":path,"maximum_absolute_delta":maximum})
        if maximum>0.00000011920928955078125:failures.append(path+": transform difference beyond one float32 unit at magnitude 1: "+str(maximum))
    elif typeof(a)!=typeof(b) and not ((a is float or a is int) and (b is float or b is int)):
        failures.append(path+": Variant type "+str(typeof(a))+" != "+str(typeof(b)))
    elif a!=b:failures.append(path+": "+str(a).left(140)+" != "+str(b).left(140))
func compare_nodes(a:Node,b:Node,path:String,seen:Dictionary)->void:
    if a.get_class()!=b.get_class():failures.append(path+": node type");return
    var actual:Dictionary={}
    for field in b.get_property_list():actual[str(field.name)]=true
    for field in a.get_property_list():
        var name:String=field.name
        if not int(field.usage)&PROPERTY_USAGE_STORAGE or name in ["script","name","owner","unique_name_in_owner"]:continue
        # Exported donor Trail properties remain part of this oracle.
        if actual.has(name):compare(a.get(field.name),b.get(field.name),path+"/"+name,seen)
    if a.get_script()!=null and a.get_script().resource_path.ends_with("/GPUTrail3D.gd"):
        # These native private fields drive the trail's actual render transform
        # and UV history; exported-property equality alone missed its entry.
        for name in ["_billboard_transform","_old_pos","_uv_offset"]:
            compare(a.get(name),b.get(name),path+"/"+name,seen)
    if a.get_child_count()!=b.get_child_count():failures.append(path+": children count "+str(a.get_children().map(func(n):return str(n.name)))+" vs "+str(b.get_children().map(func(n):return str(n.name))));return
    for i in a.get_child_count():compare_nodes(a.get_child(i),b.get_child(i),path+"/"+str(a.get_child(i).name),seen)
func pipelines()->Dictionary:
    var result:Dictionary={}
    for key in ["CANVAS","MESH","SURFACE","DRAW","SPECIALIZATION"]:
        result[key]=RenderingServer.get_rendering_info(ClassDB.class_get_integer_constant("RenderingServer","RENDERING_INFO_PIPELINE_COMPILATIONS_"+key))
    return result
func run()->void:
    Engine.max_fps=60;root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(320,240)
    var all_sources:bool="--all-sources" in OS.get_cmdline_user_args()
    var clips:Array=[]
    if all_sources:
        var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/projectiles.json"))
        for spell in manifest.spells:
            for clip in spell.clips:
                if not clip in clips:clips.append(clip)
    else:
        var index:Dictionary=Recording.read("res://.runtime/gallery-sorcerer-20261015-seed3-door/amber/journal")
        for item in index.groups:
            for component in item.group.components:
                if component.get("native_spell",false) and not component.native_clip in clips:clips.append(component.native_clip)
    var cache:Dictionary={};var deadline:int=Time.get_ticks_msec()+120000;var loaded:int=Time.get_ticks_usec();var preparation_calls:Array=[]
    while true:
        var call_start:int=Time.get_ticks_usec()
        var prepared:Dictionary=After.prepare(clips,cache)
        preparation_calls.append((Time.get_ticks_usec()-call_start)/1000.0)
        if not prepared.errors.is_empty():failures.append_array(prepared.errors);break
        if prepared.ready:break
        if Time.get_ticks_msec()>deadline:failures.append("Prepared resource loading deadline");break
        await process_frame
    var load_ms:float=(Time.get_ticks_usec()-loaded)/1000.0
    var owner=Node3D.new();root.add_child(owner)
    if failures.is_empty():
        for clip in clips:
            var original:Dictionary=Before.make(owner,clip.duplicate(true),0,false)
            var before_pipelines:Dictionary=pipelines();var begin:int=Time.get_ticks_usec()
            var revised:Dictionary=After.make(owner,clip.duplicate(true),0)
            var build_ms:float=(Time.get_ticks_usec()-begin)/1000.0
            var peer:Dictionary=After.make(owner,clip.duplicate(true),0)
            var start:int=checks;var failed:int=failures.size()
            check(original.error.is_empty() and revised.error.is_empty() and peer.error.is_empty(),clip.id+": all sources construct")
            if original.error.is_empty() and revised.error.is_empty() and peer.error.is_empty():
                before_root=original.root;after_root=revised.root
                var override_materials:Dictionary={}
                for value in clip.get("property_overrides",[]):
                    if not str(value.property).begins_with("material_override:"):continue
                    var target:GeometryInstance3D=revised.root.get_node(value.node)
                    override_materials[value.node]=target.material_override
                    check(target.get_indexed(NodePath(value.property))==original.root.get_node(value.node).get_indexed(NodePath(value.property)),clip.id+": exact authored material override "+value.property)
                for age in [0.0,.2,.7]:
                    Before.sample(original,age,0.0);After.sample(revised,age,0.0)
                    compare_nodes(original.root,revised.root,clip.id+"@"+str(age),{})
                    for path in override_materials:
                        check(is_same(revised.root.get_node(path).material_override,override_materials[path]),clip.id+": source sampling preserves the private override material "+path)
                check(peer.age==0.0,clip.id+": independent instance source age")
                for piece in revised.geometry:
                    var other:GeometryInstance3D=peer.root.get_node(piece.path)
                    if piece.node.material_override!=null:
                        check(not is_same(piece.node.material_override,other.material_override),clip.id+": independent material "+piece.path)
                    if piece.node is GPUParticles3D and piece.node.process_material!=null:
                        check(not is_same(piece.node.process_material,other.process_material),clip.id+": independent process material "+piece.path)
                for piece in revised.geometry:
                    var other:GeometryInstance3D=peer.root.get_node(piece.path)
                    var mesh:Mesh=piece.node.mesh if piece.node is MeshInstance3D else piece.node.draw_pass_1 if piece.node is GPUParticles3D else null
                    var other_mesh:Mesh=other.mesh if other is MeshInstance3D else other.draw_pass_1 if other is GPUParticles3D else null
                    if mesh!=null and other_mesh!=null:
                        for surface in mesh.get_surface_count():
                            var material:Material=mesh.surface_get_material(surface)
                            if material!=null:check(not is_same(material,other_mesh.surface_get_material(surface)),clip.id+": independent mesh material "+piece.path+"/"+str(surface))
                # A later owner cannot alter a retained source's material values.
                After.sample(peer,.1,0.0)
                compare_nodes(original.root,revised.root,clip.id+" retained@.7",{})
            rows.append({"source":clip.id,"checks":checks-start,"failures":failures.size()-failed,"make_ms":build_ms,"constructor_phases":revised.get("constructor_timings",{}),"pipelines_before":before_pipelines,"pipelines_after_make":pipelines()})
            print("NATIVE_VARIANT_CHECK ",JSON.stringify(rows.back()))
            await RenderingServer.frame_pre_draw
            Before.close(original);After.close(revised);After.close(peer)
            await process_frame;await RenderingServer.frame_post_draw
    owner.queue_free();await process_frame;await RenderingServer.frame_post_draw
    var report={"checks":checks,"failures":failures,"resource_load_ms":load_ms,"preparation_call_ms":preparation_calls,"scope_metadata":"Exported native source references are trusted; optional dependency verification is an offline tool","sources":rows,"all_sources":all_sources,"source_count":clips.size(),"transform_roundoff":transform_roundoff,"scope":"Selected real source state and ownership; CPU creation excludes preloading. Hidden source layers do not qualify visible surface pipeline stalls."}
    FileAccess.open("res://.runtime/native-source-variant"+("-all" if all_sources else "")+"-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_VARIANT_CHECK_COMPLETE ",checks," failures=",failures.size())
    for value in failures.slice(0,25):printerr(value)
    quit(0 if failures.is_empty() else 1)
