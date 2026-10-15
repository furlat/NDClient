extends SceneTree
## Native regression for concurrent material loading vs source construction.
## The original unchanged trail shader is bound by each loaded ShaderMaterial;
## loading raw Shader files alone does not force this compiler path.
const Recording=preload("res://studio/recording.gd")
const Renderer=preload("res://presentation/component_renderer.gd")
const Profile=preload("res://frame_profile.gd")
class Lighting extends RefCounted:
    func sample_handles(_handles:Dictionary)->void:pass
class BloodStub extends RefCounted:
    var deposit_create_usec:int=0
    var light_page_create_usec:int=0
    func prepare(_world:Node,_groups:Array)->bool:return true
    func close(_world:Node)->void:pass
class World extends Node3D:
    var timeline:RefCounted
    var camera:Camera3D
    var profile:Dictionary=Profile.create()
    var source_lighting=Lighting.new()
    var visual_actors:Dictionary={}
    var playbacks:Dictionary={}
    var actor_entries:Array=[]
    var catalog_cache:Dictionary={}
const Factory=preload("res://presentation/native_factory_source.gd")
const Sources=preload("res://presentation/native_effects.gd")
const Admission=preload("res://presentation/native_source_admission.gd")
var checks:int=0
var failures:Array=[]
func _initialize()->void:run.call_deferred()
func check(value:bool,label:String)->void:
    checks+=1
    if not value:failures.append(label);printerr(label)
func run()->void:
    root.unfocusable=true;root.position=Vector2i(-16000,-16000);root.size=Vector2i(320,240)
    Engine.max_fps=60
    create_timer(90).timeout.connect(func():printerr("Native admission deadline");quit(2))
    var directory:String="res://.runtime/native-source-admission"
    DirAccess.make_dir_recursive_absolute(directory)
    var native_shader:String="res://assets/native_effects/sandbox/projectiles/library/lelu/pack_lelu_godot_patreons_community_pack_3_d/addons/GPUTrail-main/shaders/trail.gdshader"
    var queues:Array=[[],[]];var caches:Array=[{},{}]
    for i in 32:
        var path:String=directory.path_join("scene-"+str(i)+".tscn")
        var shader_path:String=path.trim_suffix(".tscn")+".gdshader"
        FileAccess.open(shader_path,FileAccess.WRITE).store_string(FileAccess.get_file_as_string(native_shader)+"\n// admission fixture "+str(i)+"\n")
        FileAccess.open(path,FileAccess.WRITE).store_string('[gd_scene load_steps=3 format=3]\n[ext_resource type="Shader" path="'+shader_path+'" id="1"]\n[sub_resource type="ShaderMaterial" id="1"]\nshader = ExtResource("1")\n[node name="Trail" type="GPUParticles3D"]\nprocess_material = SubResource("1")\n')
        queues[i%2].append(path)
    var manifest:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://authoring/sandbox/projectiles.json"))
    var clips:Array=[]
    for spell in manifest.spells:
        for clip in spell.clips:
            if clip.id in ["recovered/travelIce","spells/fireball/fire/lifecycle","spells/scorching_ray/back/lifecycle","spells/chill_touch/impact/impact"]:clips.append(clip)
    check(clips.size()==4,"Four real selected source constructors participate")
    var prepared_cache:Dictionary={}
    while true:
        var prepared:Dictionary=Factory.prepare(clips,prepared_cache)
        if not prepared.errors.is_empty():failures.append_array(prepared.errors);quit(1);return
        if prepared.ready:break
        await process_frame
    var owner=Node3D.new();root.add_child(owner)
    var constructed:int=0;var loaded:int=0;var started:int=Time.get_ticks_usec()
    while not queues[0].is_empty() or not queues[1].is_empty():
        var before:int=Admission.loads_started
        var construct_due:bool=loaded>constructed*2
        for i in 2:
            if queues[i].is_empty():continue
            var path:String=queues[i][0]
            var result:Dictionary=Admission.prepare([] if construct_due else [path],caches[i])
            check(result.errors.is_empty(),"Private load owner has no admission error")
            if not construct_due and result.ready:queues[i].pop_front();loaded+=1
        check(Admission.loads_started-before<=1,"Two independent owners never launch concurrent native loads")
        check(Factory.prepare([],{}).ready,"Existing spell playback remains ready during future admission")
        check(Sources.prepare([],{}).ready,"Existing class/effect playback remains ready during future admission")
        if Admission.settling:
            check(not Admission.can_mutate(),"Loaded material waits for its normal dirty-material draw flush")
        if loaded>constructed*2 and Admission.can_mutate():
            var handle:Dictionary=Factory.make(owner,clips[constructed%clips.size()].duplicate(true),0)
            check(handle.error.is_empty(),"Real source constructs after global admission")
            constructed+=1
            before=Admission.loads_started
            for i in 2:
                if not queues[i].is_empty():Admission.prepare([queues[i][0]],caches[i])
            check(Admission.loads_started==before,"A constructor prevents a new load until after this frame's dirty flush")
            await RenderingServer.frame_post_draw
            Factory.close(handle)
        await process_frame
    while not Admission.can_mutate():await process_frame
    check(loaded==32 and constructed>0,"Every requested material and real constructor completed")
    owner.queue_free();await process_frame;await RenderingServer.frame_post_draw
    await mixed_current_sources()
    var report={"checks":checks,"failures":failures,"loaded_scenes":loaded,"constructors":constructed,"elapsed_ms":(Time.get_ticks_usec()-started)/1000.0,"scope":"Two independent native load owners, exact real trail ShaderMaterial parsing, real Gallery constructors and draw-fenced admission. Pixel/source parity is separate."}
    FileAccess.open(directory.path_join("report.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("NATIVE_SOURCE_ADMISSION ",JSON.stringify(report))
    quit(0 if failures.is_empty() else 1)

func mixed_current_sources()->void:
    var spells:Dictionary=Recording.read("res://.runtime/gallery-sorcerer-20261015-seed3-door/amber/journal")
    var actions:Dictionary=Recording.read("res://.runtime/studio-cases/action_economy-seed3-v2/amber/journal")
    check(spells.ok and actions.ok,"Both actual source recordings admit for mixed preparation")
    var native:Dictionary={};var legacy:Dictionary={}
    for item in spells.groups:
        for component in item.group.components:
            if native.is_empty() and component.get("native_spell",false):native=component.duplicate(true)
    for item in actions.groups:
        for component in item.group.components:
            if legacy.is_empty() and component.get("kind")=="native_effect" and not component.get("native_spell",false):legacy=component.duplicate(true)
    check(not native.is_empty() and not legacy.is_empty(),"Real spell and class effect provide both source families")
    if native.is_empty() or legacy.is_empty():return
    # This is an admission fixture, not a new server recording: move only the
    # selected real class cue later to expose the preparation-order deadlock.
    legacy.start_ms=500.0
    var group:Dictionary={"id":"mixed-native-admission","components":[native,legacy],"commits":[],"duration_ms":2000.0}
    var world=World.new();root.add_child(world)
    world.camera=Camera3D.new();world.add_child(world.camera)
    world.timeline=Recording.restore(spells,0.0);world.timeline.current=group
    world.timeline.queue=[];world.timeline.group_start_ms=0.0;world.timeline.display_ms=0.0
    world.catalog_cache=spells.cache
    var canonical:Dictionary=world.timeline.state.duplicate(true)
    var renderer=Renderer.new();renderer.blood=BloodStub.new()
    var deadline:int=Time.get_ticks_msec()+15000;var ready:bool=false
    while Time.get_ticks_msec()<deadline:
        var result:Dictionary=renderer.prepare([group],spells.cache,world)
        check(result.errors.is_empty(),"Mixed native family preparation has no missing-source error")
        if result.ready:ready=true;break
        await process_frame
    check(ready and renderer.native_spells.handles.has(native.id),"Later class cue cannot starve the current spell's real loading/construction")
    world.timeline.display_ms=500.0
    var result:Dictionary=renderer.prepare([group],spells.cache,world)
    check(result.ready and Admission.mutation_frame==Engine.get_process_frames(),"Now-active class construction reserves only after required spell resources are ready")
    var handle:Dictionary=Sources.make(world,Sources.source_record(legacy.source_id,spells.cache),73)
    check(handle.error.is_empty(),"Original class/effect constructor also completes under shared admission")
    check(world.timeline.state==canonical,"Preparation does not change actual server state")
    Sources.release(handle);renderer.close(world);world.queue_free()
    await process_frame;await RenderingServer.frame_post_draw
