extends SceneTree
## Baked playback against the native source it was recorded from: both are
## built in separate identical worlds, sampled at the same source times, and
## their frames compared. A late start (direct jump) must equal the frame
## reached by playing. Run with --fixed-fps 60.
##   --script res://tests/baked_effect_checks.gd -- --spells=fire_bolt [--clips=id,...]
const Baked=preload("res://presentation/baked_effect.gd")
const Factory=preload("res://presentation/native_factory_source.gd")
const Sources=preload("res://presentation/native_presentation_sources.gd")
const SIZE:=Vector2i(320,320)
const LAYER:=1<<1
## Per-channel difference that counts as a changed pixel (8-bit units).
const TOLERANCE:=8
## Changed fraction of covered pixels always accepted (edge pixels of sparks).
const MATCH:=0.15
var checks:int=0
var failures:Array=[]
var clips_report:Array=[]
## --offset=N plays the recording N frames ahead (diagnostics).
var frame_offset:int=0

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
    checks+=1
    if not ok:failures.append(label);printerr("BAKED_EFFECT_FAIL ",label)
func frame()->void:
    await process_frame;await RenderingServer.frame_post_draw

func run()->void:
    create_timer(900).timeout.connect(func():printerr("Baked effect checks deadline");quit(2))
    var arguments:Dictionary={}
    for argument in OS.get_cmdline_user_args():
        var parts:PackedStringArray=argument.trim_prefix("--").split("=",true,1)
        arguments[parts[0]]=parts[1] if parts.size()>1 else "true"
    var cache:Dictionary={}
    var owner:Dictionary=Sources.admission(cache)
    var spells:Array=arguments.get("spells","").split(",",false)
    var ids:Array=arguments.get("clips","").split(",",false)
    var save_dir:String=arguments.get("save","")
    frame_offset=int(arguments.get("offset","0"))
    for behavior in owner.index.spells:
        var record:Resource=Sources.find(behavior,cache)
        if record==null:continue
        var selection:Dictionary=record.selection
        for id in selection.get("clip_by_id",{}):
            if str(selection.get("id",behavior)) in spells or behavior in spells or id in ids:
                await compare(selection.clip_by_id[id],save_dir)
    var report={"checks":checks,"failures":failures,"clips":clips_report,
        "scope":"Baked playback versus its native source in isolated identical worlds at the recording's source times; same seeds, fixed recording step."}
    FileAccess.open("res://.runtime/baked-effect-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
    print("BAKED_EFFECT_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
    quit(0 if failures.is_empty() else 1)

func _view()->Dictionary:
    var viewport:=SubViewport.new()
    viewport.size=SIZE;viewport.own_world_3d=true;viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    var camera:=Camera3D.new();camera.cull_mask=LAYER
    var environment:=Environment.new();environment.background_mode=Environment.BG_CLEAR_COLOR
    camera.environment=environment
    viewport.add_child(camera)
    var holder:=Node3D.new();viewport.add_child(holder)
    root.add_child(viewport)
    return {"viewport":viewport,"camera":camera,"holder":holder}

func compare(clip:Dictionary,save_dir:String)->void:
    var id:String=clip.id
    Baked._bundles.erase(id);Baked._requested.erase(id)
    var bundles:Variant=Baked.request(clip)
    while bundles==null:
        await frame();bundles=Baked.request(clip)
    check(bundles is Array,"Current recording exists: "+id)
    if not bundles is Array:return
    for variant in bundles.size():await compare_variant(clip,bundles[variant],variant,save_dir)

func _native(view:Dictionary,clip:Dictionary,variant:int)->Dictionary:
    var handle:Dictionary=Factory.make(view.holder,clip,LAYER,false)
    for index in handle.emitters.size():
        handle.emitters[index].use_fixed_seed=true;handle.emitters[index].seed=Baked.bake_seed(variant)+index
        handle.emitters[index].fixed_fps=0;handle.emitters[index].interpolate=false
    return handle

## Native, a second native (control) and baked, each in its own identical
## world. Native particles are not repeatable between runs, so the baked
## recording passes when it is no further from the native frames than the
## control is (or within MATCH of their covered pixels).
func compare_variant(clip:Dictionary,bundle:Resource,variant:int,save_dir:String)->void:
    var id:String=clip.id
    var live_view:=_view();var control_view:=_view();var baked_view:=_view()
    var live:Dictionary=_native(live_view,clip,variant)
    var control:Dictionary=_native(control_view,clip,variant)
    check(live.error.is_empty() and control.error.is_empty(),"Native source builds: "+id+" "+live.error)
    var baked:Dictionary=Baked.make(baked_view.holder,bundle,clip,LAYER)
    check(baked.error.is_empty(),"Baked scene builds: "+id+" "+baked.error)
    if not live.error.is_empty() or not baked.error.is_empty():
        for view in [live_view,control_view,baked_view]:view.viewport.queue_free()
        return
    # Frame the recorded particle bounds from a raised three-quarter view.
    var bounds:=AABB()
    for system in bundle.systems:
        var particles:GPUParticles3D=baked.root.get_node(system.path)
        bounds=particles.visibility_aabb if bounds.size==Vector3.ZERO else bounds.merge(particles.visibility_aabb)
    var reach:float=maxf(0.5,bounds.get_longest_axis_size()*0.45)
    for view in [live_view,control_view,baked_view]:
        view.camera.position=bounds.get_center()+Vector3(0.0,0.6,1.0).normalized()*reach*1.3
        view.camera.look_at(bounds.get_center())
    live.root.show();control.root.show();baked.root.show()
    var frames:int=bundle.frames
    var stats:Dictionary={"clip":id,"variant":variant,"frames":frames,"baked_changed":0,"control_changed":0,"covered_pixels":0,"gaps":bundle.gaps,
        "plays_baked":Baked.ready_for(clip) is Resource}
    var played:Dictionary={}
    for step in frames:
        var seconds:float=float(step)/bundle.rate
        for handle in [live,control]:Factory.sample(handle,seconds,0.0 if step==0 else 1.0/bundle.rate,seconds)
        Baked.sample(baked,maxf(0.0,float(step+frame_offset))/bundle.rate)
        await frame()
        var a:Image=live_view.viewport.get_texture().get_image()
        var b:Image=baked_view.viewport.get_texture().get_image()
        var c:Image=control_view.viewport.get_texture().get_image()
        var against_baked:Dictionary=_difference(a,b);var against_control:Dictionary=_difference(a,c)
        stats.baked_changed+=against_baked.changed;stats.control_changed+=against_control.changed
        stats.covered_pixels+=against_baked.covered
        if step in [frames/4,frames/2]:played[step]=b
        if not save_dir.is_empty() and step%6==0:
            var base:String=save_dir.path_join(id.replace("/","__")+"_v%d_%03d"%[variant,step])
            a.save_png(base+"_live.png");b.save_png(base+"_baked.png")
    var covered:float=maxf(1.0,float(stats.covered_pixels))
    stats.baked_fraction=stats.baked_changed/covered;stats.control_fraction=stats.control_changed/covered
    check(stats.covered_pixels>0,"Source draws something: "+id)
    if stats.plays_baked:
        check(stats.baked_fraction<=maxf(stats.control_fraction,MATCH),"Baked frames are no further from the native source than a second native run (baked %.3f, native %.3f): %s v%d"%[stats.baked_fraction,stats.control_fraction,id,variant])
    # Direct jumps (late start, seek backwards) need no history.
    for step in played:
        Baked.sample(baked,0.0);await frame()
        Baked.sample(baked,float(step)/bundle.rate);await frame()
        var jumped:Image=baked_view.viewport.get_texture().get_image()
        var result:Dictionary=_difference(played[step],jumped)
        stats["jump_changed_"+str(step)]=result.changed
        if result.changed>0 and not save_dir.is_empty():
            var base:String=save_dir.path_join(id.replace("/","__")+"_v%d_jump%03d"%[variant,step])
            played[step].save_png(base+"_played.png");jumped.save_png(base+"_jumped.png")
        # Exact except where a light switches on in the jumped-to frame: one
        # small lit particle of a Magic Missile impact frame differs (18 px;
        # presumably the light's first-frame pairing). Counts are reported.
        check(result.changed<=maxi(1,int(result.covered*0.005)),"A direct jump to frame %d equals playing to it: %s v%d (%d px)"%[step,id,variant,result.changed])
    clips_report.append(stats)
    print("BAKED_EFFECT_CLIP ",JSON.stringify(stats))
    Factory.close(live);Factory.close(control);Factory.close(baked)
    for view in [live_view,control_view,baked_view]:view.viewport.queue_free()
    await frame()

func _difference(a:Image,b:Image)->Dictionary:
    var x:PackedByteArray=a.get_data();var y:PackedByteArray=b.get_data()
    var changed:int=0;var covered:int=0;var worst:int=0
    for at in range(0,mini(x.size(),y.size()),4):
        var drawn:bool=x[at+3]>0 or y[at+3]>0
        if not drawn:continue
        covered+=1
        var largest:int=0
        for c in 4:largest=maxi(largest,absi(int(x[at+c])-int(y[at+c])))
        worst=maxi(worst,largest)
        if largest>TOLERANCE:changed+=1
    return {"changed":changed,"covered":covered,"max_channel":worst}
