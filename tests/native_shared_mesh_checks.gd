extends SceneTree
## Prepared native packets share immutable ArrayMesh vertex data between
## instances instead of copying it through a GPU readback per construction.
## The shared mesh must be the exact data the per-instance copy held: same
## format, primitive, arrays, blend shapes and bounds, no surface materials,
## and unchanged after sampling live instances.
## Usage: --script res://tests/native_shared_mesh_checks.gd -- [--spells=spell.magic_missile,...]
const Factory=preload("res://presentation/native_factory_source.gd")
const Variants=preload("res://presentation/native_source_variants.gd")
const Authoring=preload("res://presentation/native_spell_authoring.gd")
var checks:=0
var failures:Array=[]

func _initialize()->void:run.call_deferred()

func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);print("SHARED_MESH_FAIL ",label)

func argument(name:String,fallback:String)->String:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with(name+"="):return arg.trim_prefix(name+"=")
    return fallback

static func snapshot(mesh:ArrayMesh)->Array:
    var result:Array=[mesh.get_aabb(),mesh.get_blend_shape_count(),mesh.blend_shape_mode,mesh.custom_aabb]
    for surface in mesh.get_surface_count():
        result.append([mesh.surface_get_format(surface),mesh.surface_get_primitive_type(surface),mesh.surface_get_arrays(surface),mesh.surface_get_blend_shape_arrays(surface),mesh.surface_get_material(surface)])
    return result

func run()->void:
    var catalog:Dictionary={};var cache:Dictionary={}
    var host:=Node3D.new();root.add_child(host)
    var spells:Array=Authoring.Sources.admission(catalog).index.spells.keys() if argument("--spells","all")=="all" else Array(argument("--spells","").split(","))
    var shared:=0;var kept:=0;var timings:Array=[]
    for behavior in spells:
        for clip in Authoring.selection(behavior,catalog).get("clips",[]):
            var loading:Dictionary=Factory.prepare([clip],cache)
            var frames:=0
            while not loading.ready and loading.errors.is_empty() and frames<4000:
                await process_frame;frames+=1;loading=Factory.prepare([clip],cache)
            check(loading.ready,str(clip.id)+": admits")
            if not loading.ready:continue
            var expected:Dictionary={}
            for spec in clip.components:
                var packet:Resource=Factory.admitted_packet(Variants.component_spec(spec,clip))
                if packet==null:continue
                var state:SceneState=packet.scene.get_state()
                for index in state.get_node_count():
                    for property in state.get_node_property_count(index):
                        var mesh:Variant=state.get_node_property_value(index,property)
                        if not mesh is ArrayMesh:continue
                        if mesh.resource_local_to_scene:kept+=1;continue
                        shared+=1
                        var materials:bool=range(mesh.get_surface_count()).any(func(surface):return mesh.surface_get_material(surface)!=null)
                        check(not materials,str(clip.id)+": a shared mesh has no surface materials")
                        # The per-instance copy instancing used to make.
                        var copy:ArrayMesh=mesh.duplicate()
                        var before:Array=snapshot(mesh)
                        check(before==snapshot(copy),str(clip.id)+": shared mesh equals its former per-instance copy "+str(state.get_node_path(index)))
                        expected[mesh]=before
            if expected.is_empty():continue
            var handles:Array=[]
            for attempt in 2:
                while not Factory.Admission.can_mutate():await process_frame
                var started:=Time.get_ticks_usec()
                var handle:Dictionary=Factory.make(host,clip.duplicate(true))
                timings.append({"clip":clip.id,"make_ms":snappedf((Time.get_ticks_usec()-started)/1000.0,0.01)})
                check(handle.error.is_empty(),str(clip.id)+": constructs "+str(handle.error))
                if handle.error.is_empty():handles.append(handle)
                await process_frame
            if handles.size()==2:
                var used:Dictionary={}
                for handle in handles:
                    for node in handle.root.find_children("*","",true,false):
                        for property in ["mesh","draw_pass_1","draw_pass_2","draw_pass_3","draw_pass_4"]:
                            if property in node and node.get(property) is ArrayMesh and expected.has(node.get(property)):used[node.get(property)]=used.get(node.get(property),0)+1
                check(used.size()==expected.size() and used.values().all(func(count):return count>=2),str(clip.id)+": both instances draw the shared meshes")
                for frame in 6:
                    for handle in handles:
                        handle.root.show()
                        Factory.sample(handle,frame/30.0,1.0/60.0)
                    await process_frame
                for mesh in expected:check(snapshot(mesh)==expected[mesh],str(clip.id)+": sampling instances leaves shared vertex data unchanged")
            for handle in handles:Factory.close(handle)
    print("SHARED_MESH_TIMINGS ",JSON.stringify(timings))
    print("SHARED_MESH ",JSON.stringify({"checks":checks,"failed":failures.size(),"shared_meshes":shared,"scene_local_meshes":kept,"failures":failures}))
    quit(0 if failures.is_empty() else 1)
